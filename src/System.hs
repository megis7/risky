module System where

import Core.RegFile
import Core.Decode
import Core.Definitions
import Core.Pipeline

import Out.Func
import Out.St_hb

import Data.Bool
import Data.Maybe (catMaybes)

import Clash.Prelude

import qualified Prelude as P

import Control.DeepSeq (NFData)

-- Hack from https://github.com/adamwalker/clash-riscv
-- fixes ROM initial value ? 
firstCycleDef' :: HiddenClockReset dom sync gated => a -> Signal dom a -> Signal dom a
firstCycleDef' defa = mealy step False
    where
    step False _ = (True, defa)
    step True  x = (True, x)

firstCycleDef :: (HiddenClockReset dom sync gated, Default a) => Signal dom a -> Signal dom a
firstCycleDef = firstCycleDef' def
-----

cpuHardware :: HiddenClockReset dom gated sync => Vec (2 ^ 5) (BitVector 32) -> Vec (2 ^ 6) (BitVector 32) -> Signal dom (Vec 10 XTYPE)
cpuHardware initialProg initialMem = output
    where
        instruction = firstCycleDef $ romPow2 initialProg (unpack . resize <$> next_pc_0)

        memBaseAddr = 0x10010000 -- Base address of data segment, generated by rars
        readAddr'  = shiftR <$> (readAddr - memBaseAddr) <*> 2 
        writeAddr'  = shiftR <$> (writeAddr - memBaseAddr) <*> 2 
        write = mux writeEnable (Just <$> bundle ((unpack . resize) <$> writeAddr', writeValue)) (pure Nothing)

        memData = firstCycleDef $ readNew (blockRamPow2 initialMem) ((unpack . resize) <$> readAddr') write     -- use readNew to enable read-after-write
                                                                                                                -- ! compiler finds meta-stability issues

        (regFile, next_pc, readAddr, writeAddr, writeValue, writeEnable) = pipeline instruction memData
        next_pc_0 = shiftR <$> (next_pc - 0x400000) <*> 2
        output = bundle $ (readReg <$> regFile <*> 1) :> (readReg <$> regFile <*> 2)  :> 
                          (readReg <$> regFile <*> 3) :> (readReg <$> regFile <*> 4)  :> 
                          (readReg <$> regFile <*> 5) :> (readReg <$> regFile <*> 6)  :> 
                          (readReg <$> regFile <*> 7) :> (readReg <$> regFile <*> 8)  :> 
                          (readReg <$> regFile <*> 9) :> (readReg <$> regFile <*> 10) :> Nil

topEntity :: Clock System Source -> Reset System Asynchronous -> Signal System (Vec 10 XTYPE)
topEntity clk rst = withClockReset clk rst $ cpuHardware (st_hb_ICache ++ repeat 0) (st_hb_DCache ++ repeat 0)