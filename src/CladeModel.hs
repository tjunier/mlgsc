-- A type class for clade models, i.e., a conserved sequence regions that should
-- be able to recognize a clade (be it a OTU, or a species, or whatever "rank").

module CladeModel (CladeModel(..), scoreOf, scoreSeq, modLength, cladeName,
    absentResScore) where

import qualified Data.Map.Strict as M
import qualified Data.Text as T
import Data.Binary (Binary, put, get, Get, Word8)

import MlgscTypes
import NucModel (NucModel, nucScoreOf, nucScoreSeq, nucModLength, nucAbsentResScore)
import PepModel
import SimplePepModel

data CladeModel = NucCladeModel NucModel
                | PepCladeModel PepModel
                | SimplePepCladeModel SimplePepModel
                deriving (Show, Eq)

scoreOf :: CladeModel -> Residue -> Position -> Int
scoreOf (NucCladeModel nm) res pos = nucScoreOf nm res pos
scoreOf (PepCladeModel pm) res pos = pepScoreOf pm res pos
scoreOf (SimplePepCladeModel spm) res pos = simplePepScoreOf spm res pos

scoreSeq :: CladeModel -> Sequence -> Int
scoreSeq (NucCladeModel nm) seq = nucScoreSeq nm seq
scoreSeq (PepCladeModel pm) seq = pepScoreSeq pm seq
scoreSeq (SimplePepCladeModel spm) seq = simplePepScoreSeq spm seq

modLength :: CladeModel -> Int
modLength (NucCladeModel nm) = nucModLength nm
modLength (PepCladeModel pm) = pepModLength pm
modLength (SimplePepCladeModel spm) = simplePepModLength spm

absentResScore :: CladeModel -> Int
absentResScore (NucCladeModel nm) = nucAbsentResScore nm
absentResScore (PepCladeModel pm) = pepAbsentResScore pm
absentResScore (SimplePepCladeModel spm) = simplePepAbsentResScore spm

cladeName :: CladeModel -> CladeName
cladeName (SimplePepCladeModel spm) = simplePepCladeName spm
cladeName _ = T.empty

instance Binary CladeModel where
    put (NucCladeModel nm) = do
        put (0 :: Word8) >> put nm
    put (PepCladeModel pm) = do
        put (1 :: Word8) >> put pm
    
    get = do
        mol <- get :: Get Word8
        case mol of
            0 -> do
                nm <- get :: Get NucModel
                return $ NucCladeModel nm
            1 -> do
                pm <- get :: Get PepModel
                return $ PepCladeModel pm

-- TODO: factor out these two
