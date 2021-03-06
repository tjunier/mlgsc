 
import Test.HUnit

import Data.Text 
import Data.Tree

import NewickParser
import NewickDumper

-- If I parse a Newick string into a tree, then dump that tree to Newick
-- again, I should obtain the same string, i.e dump(parse(nw)) == nw, or IOW
-- (dump . parse) == id. I test this on a few Newick strings below (of course
-- you have to take my word that a tree is actually parsed from the string, and
-- that said tree is dumped back to Newick).

makeNewickTestCase :: String -> Test
makeNewickTestCase newick = TestCase
    (assertEqual ("RW " ++ newick) (pack newick) nwout)
    where   nwout           = treeToNewick nwin
            (Right nwin)    = parseNewickTree newick

-- To add a test case, just add a Newick string to this list.
newicks = [
    "(A,B);"
    , "(Aeromonas,(Bacillus,Clostridium));"
    , "(A,(B,C));"
    ,"(((Deep)));"
    , "A;"
    , "(Aeromonas,(Bacillus,Clostridium)innode_lbl);"
    , "((A,B)f,((C,D)g,E)h)i;"
    ]

testCases = Prelude.map makeNewickTestCase newicks
rwtests = TestList $ Prelude.map (TestLabel "Newick R/W" ) testCases

-- The Newick parser ignores branch lengths, but trees with branch lengths
-- should parse just fine.
(Right tree10) = parseNewickTree "((A:1,B:1.2)f:3.1,((C:0.2,D:2)g:23,E:2)h:1)i:23;"
exp10 = pack "((A,B)f,((C,D)g,E)h)i;"
test10 = "with lengths" ~: exp10 @=? treeToNewick tree10

-- tests the fringe of a tree (set of leaves)

nw02 = "(Aeromonas,(Bacillus,Clostridium));"
(Right tree2) = parseNewickTree nw02
expectedFringe = Prelude.map pack ["Aeromonas", "Bacillus", "Clostridium"]
test20 = "fringe, simple" ~: expectedFringe @=? fringe tree2

-- inner node labels are not part of the fringe: this tree's fringe is the same
-- as the previous one's.

-- TODO: add this when the parser can parse inner node labels
nw03 = "(Aeromonas,(Bacillus,Clostridium)innode_lbl);"
(Right tree3) = parseNewickTree nw03
test21 = "fringe, w/innodes" ~: expectedFringe @=? fringe tree3

fringetests = TestList $ Prelude.map (TestLabel "fringe") [test20, test21]

-- tests = rwtests ++ fringetests

tests = TestList ([rwtests] ++ [fringetests])

main = do
	runTestTT tests

