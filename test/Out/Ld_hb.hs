{-# LANGUAGE NoImplicitPrelude, DataKinds, BinaryLiterals #-}

module Out.Ld_hb where

import Clash.Prelude

ld_hb_ICache = 
  (0b00000000000000000000000010010011 :: BitVector 32) :>
  (0b00000000000000001001000100000011 :: BitVector 32) :>
  (0b00000000010000001001000110000011 :: BitVector 32) :>
  (0b00000000010000001000000010010011 :: BitVector 32) :>
  (0b00000000000000001000001000000011 :: BitVector 32) :>
  (0b00000000000100001000001010000011 :: BitVector 32) :>
  (0b00000000000000000000000001100011 :: BitVector 32) :>
  Nil
ld_hb_DCache = 
  (0b00010010001101000001001000110100 :: BitVector 32) :>
  (0b01000101011001110100010101100111 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  (0b00000000000000000000000000000000 :: BitVector 32) :>
  Nil
