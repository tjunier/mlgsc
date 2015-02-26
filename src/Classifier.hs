module Classifier (
    Classifier(..),
    buildClassifier,
    classifySequenceWithExtendedTrail,
    leafOTU) where

import Data.Tree
import qualified Data.Map.Strict as M
import qualified Data.List as L
import Data.Binary (Binary, put, get, Get)
import Data.Text.Binary
import qualified Data.Text.Lazy as LT

import MlgscTypes
-- import CladeModel
import Alignment
import NucModel
import PepModel
import SimplePepModel
import Crumbs
import CladeModel (CladeModel(..), scoreSeq)

data Classifier = Classifier OTUTree (Tree CladeModel)
                deriving (Show, Eq)

instance Binary Classifier where
    put (Classifier otuTree modTree) = do
        put otuTree
        put modTree

    get = do
        otuTree <- get :: Get OTUTree
        modTree <- get :: Get (Tree CladeModel)
        return $ Classifier otuTree modTree

buildClassifier :: Molecule -> SmallProb -> ScaleFactor ->
    AlnMap -> OTUTree -> Classifier
buildClassifier mol smallProb scale alnMap otuTree 
    = case mol of
        DNA -> buildNucClassifier smallProb scale alnMap otuTree
        -- Prot -> buildPepClassifier smallProb scale alnMap otuTree
        Prot -> buildSimplePepClassifier smallProb scale alnMap otuTree

buildNucClassifier  :: SmallProb -> ScaleFactor
                    -> AlnMap -> OTUTree -> Classifier
buildNucClassifier smallprob scale map otuTree = Classifier otuTree modTree
    where   modTree         = fmap (NucCladeModel . alnToNucModel smallprob scale) treeOfAlns
            treeOfAlns      = mergeAlns treeOfLeafAlns
            treeOfLeafAlns  = fmap (\k -> M.findWithDefault [] k map) otuTree

buildPepClassifier  :: SmallProb -> ScaleFactor
                    -> AlnMap -> OTUTree -> Classifier
buildPepClassifier smallprob scale map otuTree = Classifier otuTree modTree
    where   modTree         = fmap (PepCladeModel . alnToPepModel smallprob scale) treeOfAlns
            treeOfAlns      = mergeAlns treeOfLeafAlns
            treeOfLeafAlns  = fmap (\k -> M.findWithDefault [] k map) otuTree

buildSimplePepClassifier  :: SmallProb -> ScaleFactor -> AlnMap -> OTUTree -> Classifier
buildSimplePepClassifier smallprob scale map otuTree = undefined
    where treeOfLeafNamedAlns =
            fmap (\k -> (k, M.findWithDefault [] k map)) otuTree
{-
buildSimplePepClassifier smallprob scale map otuTree = Classifier otuTree modTree
    where   modTree         = fmap (SimplePepCladeModel . alnToSimplePepModel smallprob scale) treeOfAlns
            treeOfAlns      = mergeAlns treeOfLeafAlns
            treeOfLeafAlns  = fmap (\k -> M.findWithDefault [] k map) otuTree
-}


-- Classifies a Sequence according to a NucClassifier, yielding an OutputData

classifySequenceWithExtendedTrail :: Classifier -> Sequence -> OutputData
classifySequenceWithExtendedTrail classifier@(Classifier otuTree _) query
    = OutputData trail score
    where   trail = followExtendedCrumbsWithTrail crumbs otuTree
            (score, crumbs) = scoreSequenceWithExtendedCrumbs classifier query  

-- Same thing, but with ExtCrumbs

scoreSequenceWithExtendedCrumbs (Classifier _ modTree) seq =
    dropExtendedCrumbs (scoreCrumbs seq) modTree

-- Passsed a Sequence, returns a function CladeModel -> Int that can itelf be
-- passed to dropCrumbs, thereby scoring said sequence according to a classifier
-- and obtaining a crumbs trail. IOW, this is _meant_ to be called with only one
-- argument.

scoreCrumbs :: Sequence -> CladeModel -> Int
scoreCrumbs seq mod = scoreSeq mod seq -- isn't this flip scoreSeq?

-- produces a new tree of which each node's data is a concatenation of its
-- children node's data. Meant to be called on a Tree Alignment  whose inner
-- nodes are empty. To see it in action, do
--   putStrLn $ drawTree $ fmap show $ mergeAlns treeOfLeafAlns
-- in GHCi.

mergeAlns :: Tree Alignment -> Tree Alignment
mergeAlns leaf@(Node _ []) = leaf
mergeAlns (Node _ kids) = Node mergedKidAlns mergedKids
    where   mergedKids = L.map mergeAlns kids
            mergedKidAlns = concatMap rootLabel mergedKids

leafOTU :: OutputData -> OTUName
leafOTU od = otuName
    where (otuName, _, _) = last $ trail od
