module Align where

import Data.Array
import Data.List
import qualified Data.Map as Map
import qualified Data.ByteString.Char8 as B
import qualified Data.Text.Encoding as E
import qualified Data.Text.Lazy as T
import Text.Printf

import MlgscTypes
import CladeModel


data Direction 	= None | Diag | Down | Righ	-- 'Right' is defined by Either
	deriving (Show, Eq)
	
data DPCell = DPCell {
		val ::Int,
		dir :: Direction
	} deriving (Show, Eq)

instance Ord DPCell where
	 (DPCell int1 _) <= (DPCell int2 _) = int1 <= int2

dirSym :: DPCell -> Char
dirSym c = case (dir c) of
	None -> '.'
	Diag -> '\\'	-- how the f*ck does one get a literal '\'?
	Down -> '|'
	Righ -> '-'

type DPMatrix = Array (Int,Int) DPCell

type ScoreFunction = (CladeModel mod) => (mod -> Sequence -> Int -> Int -> Int)
type GapPenalty = Int

data ScoringScheme = ScoringScheme {
		scoreFunction 	:: ScoreFunction,
		gapOPenalty	    :: GapPenalty
	}

defScoring :: ScoringScheme
defScoring = ScoringScheme {
	scoreFunction = seqISLMatScore,
	gapOPenalty = -2 }

-- First step of sequence-to-prob-matrix alignment.  Fills a dynamic programming
-- matrix (DPMatrix), with a scoring scheme, an ISLProbMatrix and a Sequence as
-- inputs. The result can be used for backtracking. Like Needleman-Wunsch, but
-- with adaptations to matching sequences to a matrix, i.e. the first column is
-- 0 instead of (i * insertion penalty), etc. -- think of the ISLProbMatrix as
-- horizontal, and of the sequence as vertical.

msdpmat :: ScoringScheme -> ISLProbMatrix -> PackedSeq -> DPMatrix
msdpmat scs mat seq  = dpmat
	where	dpmat = array ((0,0), (seq_len, mat_len)) 
			[((i,j), cell i j) | i <- [0..seq_len], j <- [0..mat_len]]
		seq_len = B.length $ bs seq
		mat_len = length mat
		cell i j
			| i == 0 && j == 0	= DPCell 0 None
			| i == 0		= DPCell (j * penalty) Righ
			| j == 0		= DPCell 0 Down
			| otherwise = maximum [
					DPCell match Diag,
					DPCell hGap Down,
					DPCell vGap Righ ]
			where
				match = val (dpmat!(i-1,j-1)) + match_score
				hGap  = val (dpmat!(i-1,  j)) + penalty
				vGap  = val (dpmat!(i  ,j-1)) + penalty
				penalty = gapOPenalty scs
				match_score = score i j
				score = (scoreFunction scs) mat seq

-- A score function for seq-vs-mat (ISLProbMatrix)

-- NOTE: a residue that is rare but not unknown should not have a penalty
-- stronger than a gap penalty, or strange things will happen.
-- It might be better to take gap penalties into account when designing these
-- score functions.

seqISLMatScore :: ScoreFunction
seqISLMatScore hmat vseq i j
	| prob == -4000 = -1	-- not found at that position
	| prob == 0 	= 3
	| prob > -300 	= 2	-- ~ 1000 * log10(0.5)
	| prob > -600 	= 1	-- ~ 1000 * log10(0.25)
	| otherwise	= 0
	where 	prob = Map.findWithDefault (-4000) res dist
		dist = hmat !! (j-1)
		res = B.index (bs vseq) (i-1)

{-
topCell :: Array (Int,Int) DPCell -> (Int,Int)
topCell mat = fst $ maximumBy cellCmp (assocs mat)
	where cellCmp (ix1, (DPCell val1 _)) (ix2, (DPCell val2 _))
		| val1 > val2	= GT
		| otherwise	= LT
-}

msalign :: ScoringScheme -> ISLProbMatrix -> Sequence -> T.Text
msalign scs mat seq = T.pack $ nwMatBacktrack (msdpmat scs mat pseq) pseq
	where pseq = PackedSeq $ E.encodeUtf8 $ T.toStrict seq

{-
nwMatPath :: RawProbMatrix -> String -> String
nwMatPath hm vs = toPathMatrix (fmap dirSym (nw seqMatScore (-1) hra vra))
	where 	hra = Mat hm (length hm)
		vra = Seq vs (length vs)
-}

-- TODO: according to DP matrix graph, this function may actually be
-- superfluous: if we just start from the lower right corner, we'll end up with
-- the same aligned sequence and spare ourselves a O(n^2) search for the best
-- cell.

topCellInLastCol :: Array (Int,Int) DPCell -> (Int,Int)
topCellInLastCol mat = fst $ maximumBy cellCmp $
	map (\ix -> (ix, mat ! ix)) lastCol 
	where 	(lv,lh) = snd $ bounds mat
		lastCol = [(i,lh) | i <- [0..lv]] 
		cellCmp (ix1, (DPCell val1 _)) (ix2, (DPCell val2 _))
			| val1 > val2	= GT
			| otherwise	= LT

-- Traces the path back from corner to corner (NW matrix), but the horizontal
-- "sequence" is a matrix (the vertical sequence is still a sequence, though);
-- yields only the aligned sequence (not the matrix).

nwMatBacktrack :: DPMatrix -> PackedSeq -> String
nwMatBacktrack mat v = reverse va
	where  	va = nwMatBacktrack' mat topLastCol v
		topLastCol = topCellInLastCol mat

nwMatBacktrack' :: DPMatrix -> (Int,Int) -> PackedSeq -> String
nwMatBacktrack' _ (0,0) _ = ""
-- These two cases may actually be covered by the general case
nwMatBacktrack' mat (0,j) v = '-':vRest
	where vRest = nwMatBacktrack' mat (0,j-1) v
nwMatBacktrack' mat (i,0) v = ""
	where vRest = nwMatBacktrack' mat (i-1,0) v
nwMatBacktrack' mat (i,j) v = 
	case dir (mat!(i,j)) of
		Diag -> (B.index (bs v) (i-1)):vRest
			where vRest = nwMatBacktrack' mat (i-1,j-1) v
		Righ -> '-':vRest
			where vRest = nwMatBacktrack' mat (i, j-1) v
		Down -> vRest
			where vRest = nwMatBacktrack' mat (i-1, j) v
--
-- These are for debugging
-- TODO: uncomment (and adapt) when switch to ByteString works
--
-- prints out a 2D array (such as a DP matrix)
{-
toPathMatrix :: Array (Int,Int) Char -> String
toPathMatrix a = intercalate "\n" (a2Rows a)

{-
dumpNWPathMat :: ScoreFunction -> GapPenalty -> String -> String -> String
dumpNWPathMat w g h v = toPathMatrix (fmap dirSym (nw w g hra vra))
	where 	hra = Seq h (length h)
		vra = Seq v (length v)
dumpNWValMat :: ScoreFunction -> GapPenalty -> String -> String -> String
dumpNWValMat scs g h v = intercalate "\n" lines
	where 	lines = map show $ a2Rows $ fmap val $ nw w g hra vra
		hra = Seq h (length h)
		vra = Seq v (length v)
-}

-- Takes a 2D Array of e and returns a list of e, one per row.

a2Rows :: Array (Int,Int) e -> [[e]]
a2Rows a = toRows (elems a) ((snd $ snd $ bounds a) + 1)

toRows :: [e] -> Int -> [[e]]
toRows [] _ = []
toRows es n = take n es:toRows (drop n es) n

dpMatrixToSVG :: ISLProbMatrix -> Sequence -> DPMatrix -> ScoringScheme -> String
dpMatrixToSVG islmat seq dpmat scs = svgHeader ++ defs ++ matrixSVG islmat seq dpmat scs ++ svgFooter

svgHeader :: String
svgHeader = "<?xml version='1.0' standalone='no'?> \
	\ <!DOCTYPE svg PUBLIC '-//W3C//DTD SVG 1.1//EN' \
	\ 'http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd'> \
	\ <svg xmlns='http://www.w3.org/2000/svg' \
	\ xmlns:xlink='http://www.w3.org/1999/xlink' \
	\ version='1.1'>"


unitSquare :: Int
unitSquare = 50

halfUSquare :: Int
halfUSquare = unitSquare `div` 2

endSpace :: Int
endSpace = 5

unitLength :: Int
unitLength = unitSquare - 2 * endSpace

defs :: String
defs = "<defs>" ++ css ++ icell ++ tcell ++
	lcell ++ righ ++ diag ++ down ++ "</defs>"
	where 	css = "<style type='text/css'><![CDATA[ \
			\ .edge { \
			\ fill:grey; \
			\ stroke:none; \
			\ font-style:italic; \
			\ } \
			\ .node { \
			\ fill:black; \
			\ stroke:none; \
			\ font-weight:bold; \
			\ } \
			\ ]]></style>"
		icell = printf "<g id='icell'> \
			\ <path d='M %d %d l %d %d' stroke='black' /> \
			\ <path d='M %d %d v %d' stroke='blue' /> \
			\ <path d='M %d %d h %d' stroke='red' /> \
			\ </g>"
			endSpace endSpace unitLength unitLength
			unitSquare endSpace unitLength
			endSpace unitSquare unitLength
		tcell = printf "<path id='tcell' d='M %d %d h %d' stroke='red' />"
			endSpace unitSquare unitLength
		lcell = printf "<path id='lcell' d='M %d %d v %d' stroke='blue' />"
			unitSquare endSpace unitLength
		diag =  printf "<path id='Diag' d='M %d %d l %d %d' \
			\ stroke='green' stroke-width='2' />"
			endSpace endSpace unitLength unitLength
		down =  printf "<path id='Down' d='M %d %d v %d' \
			\ stroke='green' stroke-width='2' />"
			unitSquare endSpace unitLength
		righ =  printf "<path id='Righ' d='M %d %d h %d' \
			\ stroke='green' stroke-width='2' />"
			endSpace unitSquare unitLength
			

-- Computes a SVG representation of a DP matrix. Note that matrix coordinates
-- and SVG coordinates are reversed, i.e. in a matrix (i,j), i refers to rows
-- (and hence "grows downwards" while j refers to columns and "grows leftwards",
-- whereas in an SVG canvas' coordinate (x,y), x "grows leftwards" and y "grows
-- downwards".

matrixSVG :: ISLProbMatrix -> Sequence -> DPMatrix -> ScoringScheme -> String
matrixSVG islmat seq dpmat scs = foldl1 (++) (icellSVGs ++ tcellSVGs ++ lcellSVGs)
	where 	icellSVGs = map (innerCellToSVG islmat seq scs)
			[ c | c@((i,j),_) <- (assocs dpmat), i * j /= 0 ]
		tcellSVGs = map topCellToSVG
			[ c | c@((i,j),_) <- (assocs dpmat), i == 0, j > 0 ]
		lcellSVGs = map leftCellToSVG
			[ c | c@((i,j),_) <- (assocs dpmat), i > 0, j == 0 ]

innerCellToSVG :: ISLProbMatrix -> Sequence -> ScoringScheme -> ((Int, Int), DPCell) -> String
innerCellToSVG mat seq scs ((i,j),cell) =
	printf "<use x='%d' y='%d' xlink:href='#icell'/> \				\ <text x='%d' y='%d' class='node'>%d</text> \
	\ <use x='%d' y='%d' xlink:href='#%s'/> \
	\ <text x='%d' y='%d' class='edge'>%d</text> \
	\ <text x='%d' y='%d' class='edge'>%d</text> \
	\ <text x='%d' y='%d' class='edge'>%d</text>"
	(j * unitSquare) (i * unitSquare)
	((j+1) * unitSquare) ((i+1) * unitSquare) (val cell)
	(j * unitSquare) (i * unitSquare) (show $ dir cell)
	((j+1) * unitSquare) (i * unitSquare + halfUSquare) (gapOPenalty scs)
	(j * unitSquare + halfUSquare) ((i+1) * unitSquare) (gapOPenalty scs)
	(j * unitSquare + halfUSquare) (i * unitSquare + halfUSquare) sc
	where sc = (scoreFunction scs) mat seq i j 



topCellToSVG :: ((Int, Int), DPCell) -> String
topCellToSVG ((_,j),cell) = printf "<use x='%d' y='0' xlink:href='#tcell'/> \
				\ <text x='%d' y='%d'>%d</text>"
				(j * unitSquare)
				((j+1) * unitSquare) unitSquare (val cell)

leftCellToSVG :: ((Int, Int), DPCell) -> String
leftCellToSVG ((i,_),cell) = printf "<use x='0' y='%d' xlink:href='#lcell'/> \
				\ <text x='%d' y='%d'>%d</text>"
				(i * unitSquare) 
				unitSquare ((i+1) * unitSquare) (val cell)


svgFooter :: String
svgFooter = "</svg>"

-- SVG versions of backtracing

-- TODO: uncomment (and adapt) this when switch to ByteString seems to work.
{-
nwMatBacktrackSVG :: DPMatrix -> String -> String
nwMatBacktrackSVG mat v = reverse va
	where  	va = nwMatBacktrack' mat topLastCol v
		topLastCol = topCellInLastCol mat
-}

{-
nwMatBacktrackSVG' :: DPMatrix -> (Int,Int) -> String -> String
nwMatBacktrackSVG' _ (0,0) _ = ""
-- These two cases may actually be covered by the general case
nwMatBacktrack' mat (0,j) v = '-':vRest
	where vRest = nwMatBacktrack' mat (0,j-1) v
nwMatBacktrack' mat (i,0) v = ""
	where vRest = nwMatBacktrack' mat (i-1,0) v
nwMatBacktrack' mat (i,j) v = 
	case dir (mat!(i,j)) of
		Diag -> (v!!(i-1)):vRest
			where vRest = nwMatBacktrack' mat (i-1,j-1) v
		Righ -> '-':vRest
			where vRest = nwMatBacktrack' mat (i, j-1) v
		Down -> vRest
			where vRest = nwMatBacktrack' mat (i-1, j) v
-}

diagAt :: Int -> Int -> String
diagAt i j = "<use x='" ++ x ++ "' y='" ++ y ++ "' xlink:href='#diag'/>"
	where x = show $ i * 25
	      y = show $ j * 25
-}
