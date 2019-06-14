{-# LANGUAGE NoImplicitPrelude, DataKinds, BinaryLiterals #-}

module Out.Ld_noalign where

import Clash.Prelude

ld_noalign_ICache = 
  (0b00001111110000010000000010010111 :: BitVector 32) :>
  (0b00000000000000001000000010010011 :: BitVector 32) :>
  (0b00000000000100001001000100000011 :: BitVector 32) :>
  (0b00000000000000000000000001100011 :: BitVector 32) :>
  Nil
ld_noalign_DCache = 
  (0b00010010001101000101011001111000 :: BitVector 32) :>
  (0b01000101011001111000100110101011 :: BitVector 32) :>
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