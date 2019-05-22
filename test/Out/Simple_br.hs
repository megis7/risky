{-# LANGUAGE NoImplicitPrelude, DataKinds, BinaryLiterals #-}

module Out.Simple_br where

import Clash.Prelude

simple_br_ICache = 
  (0b00000000000100000000000010010011 :: BitVector 32) :>
  (0b00000000001000000000000100010011 :: BitVector 32) :>
  (0b00000010000000001000000001100011 :: BitVector 32) :>
  (0b00000000001100000000000110010011 :: BitVector 32) :>
  (0b00000000010000000000001000010011 :: BitVector 32) :>
  (0b00000000010100000000001010010011 :: BitVector 32) :>
  (0b00000000000000000000100001100011 :: BitVector 32) :>
  (0b00000000011000000000001100010011 :: BitVector 32) :>
  (0b00000000011100000000001110010011 :: BitVector 32) :>
  (0b00000000100000000000010000010011 :: BitVector 32) :>
  (0b00000000100100000000010010010011 :: BitVector 32) :>
  (0b00000000000000000000000001100011 :: BitVector 32) :>
  Nil
simple_br_DCache = 
  Nil
