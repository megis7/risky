{-# LANGUAGE ScopedTypeVariables #-} 
{-# LANGUAGE NoImplicitPrelude #-} 
{-# LANGUAGE TypeOperators #-} 
{-# LANGUAGE DataKinds #-} 
{-# LANGUAGE FlexibleContexts #-} 
{-# LANGUAGE TypeApplications #-} 
{-# LANGUAGE BinaryLiterals #-} 
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TypeFamilies #-}

module Spec where

import Test.Hspec
-- import Test.QuickCheck
import Control.Exception (evaluate)

import qualified Prelude as P

import Core.RegFile
import Core.Decode
import Core.Definitions
import Core.Pipeline
import Data.Bool
import Data.Maybe (catMaybes)

import Clash.Prelude
import Debug.Trace

import Out.Fib
import Out.Func
import Out.Ld_hb
import Out.Ld_word
import Out.Nat_sum
import Out.Prod
import Out.Simple_br
import Out.Simple_jal
import Out.Simple

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


-- defaultCPUState = CPUState Fetch (Registers { general = repeat 0, pc = 0})

-- mapOutRegisters (pc, x) = (unpack pc :: XSigned, fmap unpack x :: [XSigned])

samples = [
  sampleN 20 $ cpuHardware (nat_sum_ICache ++ repeat 0) (nat_sum_DCache ++ repeat 0),
  sampleN 20 $ cpuHardware (fib_ICache ++ repeat 0) (fib_DCache ++ repeat 0),
  sampleN 20 $ cpuHardware (prod_ICache ++ repeat 0) (prod_DCache ++ repeat 0),
  sampleN 20 $ cpuHardware (func_ICache ++ repeat 0) (func_DCache ++ repeat 0),
  sampleN 20 $ cpuHardware (ld_word_ICache ++ repeat 0) (ld_word_DCache ++ repeat 0),
  sampleN 20 $ cpuHardware (ld_hb_ICache ++ repeat 0) (ld_hb_DCache ++ repeat 0)
  ]

-- simulations = P.fmap (\x -> fmap mapOutRegisters $ catMaybes $ x) samples

-- main :: IO ()
-- main = hspec $ do
--   describe "System-Simple CPU" $ do
--     it "calculates sum of 5 first natural numbers"    $ do (P.last (samples P.!! 0)) `shouldBe` (0 :> 0 :> 6 :> 15 :> 0 :> 0 :> Nil)
--     it "calculates 5th fibonacci number"              $ do P.last (simulations P.!! 1) `shouldBe` (44, [0, 3, 5, 6, 5, 6])
--     it "calculates product of 5, 7"                   $ do P.last (simulations P.!! 2) `shouldBe` (32, [0, 5, 7, 35, 0, 0])
--     it "call dummy function"                          $ do P.last (simulations P.!! 3) `shouldBe` (16, [0, 10, 25, 35, 35, 12])
--     it "loads words from memory"                      $ do P.last (simulations P.!! 4) `shouldBe` (24, [0, 4, 0x12341234, 0x45674567, 0x12341234, 0x45674567])
--     it "loads half words and bytes from memory"       $ do P.last (simulations P.!! 5) `shouldBe` (24, [0, 4, 0x1234, 0x4567, 0x67, 0x67])       -- * memory is word-addressable (check ld_hb.asm - final register should have value 0x45)