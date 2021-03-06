module TaxoParser where

import Data.Tree
import qualified Data.Text as ST

import MlgscTypes

type TaxoLine = [OTUName]

parseTaxonomy :: String -> OTUTree
parseTaxonomy taxo = foldl addTaxoLine (Node ST.empty []) taxolines
    where   taxolines = map (fixlast . ST.splitOn (ST.pack "; ")) $ ST.lines $ ST.pack taxo

-- The last element of a taxo list must be stripped of any trailing ';', also, I
-- replace any spaces with underscores.
--
fixlast :: [ST.Text] -> [ST.Text]
fixlast taxolist = init taxolist ++ [fix $ last taxolist]
    where fix = ST.replace (ST.pack " ") (ST.pack "_") .  ST.dropAround (== ';')

addTaxoLine :: OTUTree -> TaxoLine -> OTUTree
addTaxoLine n []    = n
addTaxoLine (Node l []) (t:ts) = Node l [kid] 
    where kid = addTaxoLine (Node t []) ts 
addTaxoLine (Node l kids) (t:ts)
    | elem t (map rootLabel kids) = Node l kids'
    | otherwise = Node l (kid:kids)
    where kid = addTaxoLine (Node t []) ts
          kids' = map   (\kid ->
                            if t == rootLabel kid
                                then addTaxoLine kid ts
                                else kid
                        ) kids

-- sandbox

taxo = ST.pack $ unlines [
    "Mammalia; Eutheria; Euarchontoglires; Rodentia; Mus; Mus musculus",
    "Mammalia; Eutheria; Laurasiatheria; Cetartiodactyla; Orcinus; Orcinus orca",
    "Mammalia; Prototheria; Monotremata; Ornithorhynchus; Ornithorhynchus anatinus",
    "Mammalia; Eutheria; Euarchontoglires; Rodentia; Sciurus; Sciurus vulgaris",
    "Mammalia; Eutheria; Afrotheria; Elephantidae; Loxodonta; Loxodonta africana"]

r = Node ST.empty []
l1 = ST.splitOn (ST.pack "; ") $ head $ ST.lines taxo
l2 = ST.splitOn (ST.pack "; ") $ ST.lines taxo !! 1

t1 = addTaxoLine r l1
t2 = addTaxoLine t1 l2

taxolines = map (ST.splitOn (ST.pack "; ")) $ ST.lines taxo
tn = foldl addTaxoLine (Node ST.empty []) taxolines
