{-# LANGUAGE DeriveGeneric, DeriveAnyClass, ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards, OverloadedStrings #-}

module Core.Pipeline where

import Core.RegFile
import Core.Fetch
import Core.Decode
import Core.Execute
import Core.Memory
import Core.Writeback
import Core.Definitions

import Clash.Prelude

import Data.Bool

instructionFetch instruction branchInstr controlTransfer_1 controlTransfer_2 controlTarget_2 shouldStallMem = (pc, next_pc, instr)
    where
        pc = register (-4) next_pc
        next_pc = nextPCMux <$> pc <*> controlTransfer_1 <*> controlTransfer_2 <*> controlTarget_2 <*> shouldStallMem
        instr = mux (controlTransfer_1 .||. controlTransfer_2 .||. shouldStallMem) 0 instruction

        -- When jumping, current pc points to the next instruction (assume not taken branch)
        -- output NOP for one cycle -> branch instruction then enters execute stage
        -- if branch is taken -> NOP for another cycle (the current one) since the fetched instruction is bad (assumed not taken branch)

        nextPCMux curPC _ _ _ True = curPC
        nextPCMux curPC ctl_1 ctl_2 trg False = case (ctl_1, ctl_2) of
            (False, True)  -> trg
            (False, False) -> curPC + 4
            (True, _)      -> curPC


instructionDecode :: Signal dom XTYPE
    -> Signal dom XTYPE
    -> Signal dom XTYPE
    -> Signal dom (Vec 32 XTYPE)
    -> (Signal dom XTYPE, Signal dom XTYPE, Signal dom Bool,
        Signal dom Bool, Signal dom Bool, Signal dom Bool,
        Signal dom ForwardingStage, Signal dom ForwardingStage)
instructionDecode instruction nextInstruction nnextInstruction regFile = (rs1Data, rs2Data, controlTransfer, shouldStallMem, alu1Register, alu2Register, fwdRs1, fwdRs2)
    where 
        rs1Addr = rs1 <$> instruction
        rs2Addr = rs2 <$> instruction
        rdAddr  = rd  <$> instruction

        rs1Data = readReg <$> regFile <*> rs1Addr' where rs1Addr' = unpack <$> rs1Addr
        rs2Data = readReg <$> regFile <*> rs2Addr' where rs2Addr' = unpack <$> rs2Addr

        controlTransfer = jal <$> instruction .||. jalR <$> instruction .||. branch <$> instruction

        -- stall when the next instruction is a load with the same destination register as one of the source registers of this instruction
        shouldStallMem = (load <$> nextInstruction)                           .&&.
                    (((rs1Addr .==. rdAddr) .&&. (usesRs1 <$> instruction) )  .||. 
                     ((rs2Addr .==. rdAddr) .&&. (usesRs2 <$> instruction) ))

        alu1Register = usesRs1 <$> instruction
        alu2Register = usesRs2 <$> instruction

        fwdRs1 = forwardingStageMux <$> rs1Addr' <*> nextInstruction <*> nnextInstruction <*> shouldStallMem where rs1Addr' = unpack <$> rs1Addr
        fwdRs2 = forwardingStageMux <$> rs2Addr' <*> nextInstruction <*> nnextInstruction <*> shouldStallMem where rs2Addr' = unpack <$> rs2Addr

        forwardingStageMux rsAddr instrEx instrMem stallMem
            | (rsAddr :: Index 32) == 0                                         = FwNone
            | unpack (rd instrEx)  == rsAddr && usesRd instrEx                  = FwEx
            | unpack (rd instrMem) == rsAddr && usesRd instrMem                 = FwMem
            | otherwise                                                         = FwNone

instructionExecute :: Signal dom XTYPE
    -> Signal dom XTYPE
    -> Signal dom XTYPE
    -> Signal dom XTYPE
    -> Signal dom Bool
    -> Signal dom Bool
    -> Signal dom ForwardingStage
    -> Signal dom ForwardingStage
    -> Signal dom XTYPE
    -> Signal dom XTYPE
    -> (Signal dom XTYPE, Signal dom Bool, Signal dom XTYPE, Signal dom Bool, Signal dom XTYPE)
instructionExecute instruction pc2 rs1Data rs2Data aluUsesRs1 aluUsesRs2 fwType1 fwType2 fwMem fwWB = (executeResult, bruRes, controlTarget, writesToRegFile, effectiveRs2)
    where
        aluOpcode = decodeAluOpcode <$> instruction
        bruOpcode = decodeBruOpcode <$> instruction
        writesToRegFile = usesRd <$> instruction

        -- ALU operands

        luiImm = calcLui <$> instruction
        immData' = mux (auipc <$> instruction) luiImm ((signExtend . iImm) <$> instruction)      -- auipc uses same immediate as LUI
        immData  = mux (store <$> instruction) ((signExtend . sImm) <$> instruction) immData'
        effectiveRs1 = fwMux <$> fwType1 <*> rs1Data <*> fwMem <*> fwWB
        effectiveRs2 = fwMux <$> fwType2 <*> rs2Data <*> fwMem <*> fwWB

        aluOperand1 = mux aluUsesRs1 effectiveRs1 pc2
        aluOperand2 = mux aluUsesRs2 effectiveRs2 immData

        -- Branch targets and execution results

        branchTrg = shiftL <$> ((signExtend . bImm) <$> instruction) <*> 1
        jalTrg    = shiftL <$> ((signExtend . jImm) <$> instruction) <*> 1

        aluRes = alu <$> aluOpcode <*> aluOperand1 <*> aluOperand2         -- when executing auipc operands will be (pc2, immData) 
        bruRes = bru <$> bruOpcode <*> aluOperand1 <*> aluOperand2
        
        executeResult = executeResultMux <$> instruction <*> aluRes <*> luiImm <*> pc2
        controlTarget = controlTargetMux <$> instruction <*> branchTrg <*> jalTrg <*> aluRes <*> pc2

        -- Helper functions
        
        calcLui instr = uImm instr ++# (0 :: BitVector 12)

        fwMux fwType rs ex mem = case fwType of
            FwNone  -> rs
            FwEx    -> ex
            FwMem   -> mem

        controlTargetMux instr bTarget jTarget jrTarget pc
            | branch instr  = pc + bTarget
            | jal instr     = pc + jTarget
            | jalR instr    = jrTarget
            | otherwise     = 0

        executeResultMux instr aluRes luiRes pc
            | jal instr || jalR instr = pc + 4
            | lui instr = luiRes
            | otherwise = aluRes

pipeline fromInstructionMem fromDataMem = (theRegFile, next_pc_0, readAddr_2, writeAddr_3, writeValue_3, writeEnable_3)
    where
        -- Stage 0
        (pc_0, next_pc_0, instr_0) = instructionFetch fromInstructionMem instr_2 controlTransfer_1 controlTransfer_2 controlTarget_2 shouldStall

        -- Stage 1
        pc_1 = register 0 $ mux shouldStall pc_1 pc_0
        instr_1' = register 0 $ mux shouldStall instr_1' instr_0
        instr_1  = mux shouldStall 0 instr_1'
        theRegFile = regFile rdAddr_4 regWriteEnable_4 rdData_4  -- we first write the result of WB and then read rs1 and rs2

        (rs1Data_1, rs2Data_1, controlTransfer_1, shouldStall, aluUsesRs1_1, aluUsesRs2_1, fwdRs1_1, fwdRs2_2) 
                = instructionDecode instr_1' instr_2 instr_3 theRegFile

        -- Stage 2
        pc_2    = register 0 pc_1
        instr_2 = register 0 instr_1
        rs1Data_2 = register 0 rs1Data_1
        rs2Data_2 = register 0 rs2Data_1
        aluUsesRs1_2 = register False aluUsesRs1_1 
        aluUsesRs2_2 = register False aluUsesRs2_1 
        forwardRs1_2 = register FwNone fwdRs1_1
        forwardRs2_2 = register FwNone fwdRs2_2
        ctlTransf_2 = register False controlTransfer_1
        controlTransfer_2 = ctlTransf_2 .&&. (bruRes_2 .||. jal <$> instr_2 .||. jalR <$> instr_2)

        accessMem_2 = load <$> instr_2 .||. store <$> instr_2
           
        (execRes_2, bruRes_2, controlTarget_2, writesToRegFile_2, effectiveRs2_2) = 
            instructionExecute instr_2 pc_2 rs1Data_2 rs2Data_2 aluUsesRs1_2 aluUsesRs2_2 forwardRs1_2 forwardRs2_2 memRes_3 rdData_4  

        readAddr_2 = execRes_2
                
        -- Stage 3 (the word at address 'readAddr_3' is read from the data cache and is available for processing here)
        pc_3 = register 0 pc_2
        instr_3 = register 0 instr_2
        effectiveRs2_3 = register 0 effectiveRs2_2
        regWriteEnable_3 = register False writesToRegFile_2
        isLoad_3 = load <$> instr_3
        isStore_3 = store <$> instr_3
        execRes_3 = register 0 execRes_2

        readAddr_3 = register 0 readAddr_2
        writeAddr_3 = execRes_3
        writeValue_3 = getStoreData <$> fromDataMem <*> effectiveRs2_3 <*> byteStart_3 <*> byteCount_3
        writeEnable_3 = store <$> instr_3

        byteStart_3 = slice d1 d0 <$> readAddr_3
        byteCount_3 = getByteCount <$> (funct3 <$> instr_3)
        isUnsigned_3 = slice d2 d2 <$> (funct3 <$> instr_3)
        getByteCount f3 = case slice d1 d0 f3 of
            0b00 -> 1
            0b01 -> 2
            0b10 -> 4
            _    -> 0 :: BitVector 3

        isMisaligned_3 = getMisalignedHard <$> byteStart_3 <*> byteCount_3

        -- Soft misalignment can be neglected
        getMisalignedSoft start count = case start of
            0b00 -> False
            0b01 -> count == 4 || count == 2
            0b10 -> count == 4
            0b11 -> count == 4 || count == 2
        
        -- Hard misalignment requires stall to fetch data (2-cycle fetch)
        getMisalignedHard start count = case start of
            0b00 -> False
            0b01 -> count == 4
            0b10 -> count == 4
            0b11 -> count == 4 || count == 2

        getStoreData datum write start count = case count of
            1 -> alignByte
            2 -> alignHalf
            4 -> write
            _ -> 0xDEADBABA
            where
                write16 = slice d15 d0 write
                write8  = slice d7 d0 write
                alignHalf = case start of
                    0 -> slice d31 d16 datum ++# write16
                    1 -> slice d31 d24 datum ++# write16 ++# slice d7 d0 datum
                    2 -> write16 ++# slice d15 d0 datum
                alignByte = case start of
                    0 -> slice d31 d8 datum ++# write8
                    1 -> slice d31 d16 datum ++# write8 ++# slice d7 d0 datum
                    2 -> slice d31 d24 datum ++# write8 ++# slice d15 d0 datum
                    3 -> write8 ++# slice d23 d0 datum   

        getLoadData datum unsigned start count = case count of
            1 -> (bool signExtend zeroExtend isUnsigned) $ slice d31 d24 datum8
            2 -> (bool signExtend zeroExtend isUnsigned) $ slice d31 d16 datum16
            4 ->                                           datum32
            _ ->                                           0xDEADBEEF                    -- error, should never happen 
            where 
                u x = unpack $ pack x :: XUnsigned
                datum8 = shiftL (u datum) (unpack $ zeroExtend $ shamt8)
                datum16 = shiftL (u datum) (unpack $ zeroExtend $ shamt16)
                datum32 = datum
                isUnsigned = unsigned == 1
                shamt16 = case start of
                    0b00 -> 2 * 8
                    0b01 -> 1 * 8       -- softly unaligned (resides in the 4-byte word read from memory. we can cope with that)
                    0b10 -> 0 * 8
                    _    -> 0 :: BitVector 5
                shamt8 = case start of
                    0b00 -> 3 * 8
                    0b01 -> 2 * 8
                    0b10 -> 1 * 8
                    0b11 -> 0 * 0 :: BitVector 5

        memRead_3 = getLoadData <$> fromDataMem <*> isUnsigned_3 <*> byteStart_3 <*> byteCount_3 
        memRes_3 = mux isLoad_3 memRead_3 execRes_3   

        -- Stage 4
        pc_4 = register 0 pc_3
        instr_4 = register 0 instr_3
        execRes_4 = register 0 memRes_3
        rdAddr_4 = (unpack . rd) <$> instr_4
        regWriteEnable_4 = register False regWriteEnable_3

        rdData_4 = execRes_4
