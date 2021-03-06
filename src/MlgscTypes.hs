module MlgscTypes where

import Data.Text
import Data.Tree
import Data.Set (fromList)

data Molecule = DNA | Prot
    deriving (Show, Eq, Read)

amino_acids = fromList "ACDEFGHIKLMNPQRSTVWY-"

data PhyloFormat = Newick | Taxonomy
    deriving (Show)

type SeqID          = Text
type Sequence       = Text
type Column         = Text
type Residue        = Char
type Position       = Int
type OTUName        = Text  -- TODO: s/OTU/Taxon/g...
type CladeName      = Text
type OTUTree        = Tree OTUName
type ScaleFactor    = Double -- TODO shouldn't this be an Int?
type SmallProb      = Double
type Score          = Int
type NewickTree     = Tree Text -- TODO: use this type!
type IDTaxonPair    = (SeqID, OTUName)

-- A classification step at one node in the model tree, in which the OTU name of
-- best model, score of best model, score of next-best, and log10 Evidence Ratio
-- are stored.

data Step = PWMStep {
                otuName             :: OTUName -- TODO: rename to taxonName
                , bestScore         :: Score
                , secondBestScore   :: Score
                , log10ER           :: Double
                }
                deriving (Show)

-- A trail of classification steps. Starts at the root of the tree and ends at a
-- leaf.

type Trail          = [Step]
