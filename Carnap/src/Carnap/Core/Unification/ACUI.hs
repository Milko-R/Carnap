module ACUI () where

import Data.List
import qualified Data.IntMap.Lazy as IntMap

--to solve ACUI unification with constants we need to be able to find
--all minimal solutions to a SAT problem

class SatProblem t where
    unitProp :: Int -> t -> Maybe t
    units :: t -> [Int]
    unassigned :: t -> [Int]
    maxLiteral :: t -> Int
    valuation :: t -> [Int]

data IntMapSat = IntMapSat {
  imValuation :: [Int]
  imUnassigned :: [Int],
  imUnits :: [Int],
  imProb :: IntMap [Int],
  imMaxLit :: Int
}

--a SatProblem instance with constant time for all operations except unitProp
--which is a kinda expensive logrithmic factor
instance SatProblem IntMapSat where
    units = imUnits
    unassigned = imUnassigned
    maxLiteral = imMaxLit
    valuation = imValuation
    unitProp x prob | single ns = Nothing
                    | otherwise = IntMapSat valu unassign myunits res (maxLiteral prob)
        where t = imProb prob
              toDelete = t ! x
              (Just ns, noneg) = insertLookupWithKey (\_ _ -> []) (negate x) [] t
              res = IntMap.map (\\ toDelete) noneg
              single [x] = True
              single _   = False
              valu = ([x] `union` valuation prob)
              unassign = delete x (unassigned prob)
              myunits = delete x (units prob)

--compSols x y == false iff x >= y
--you should add x to a set of minimal solutions if x compSols x y holds for all
--other solutions
compSols :: [Int] -> [Int] -> Bool
compSols x y = not . null $ (filter (> 0) y) // (filter (> 0) x)
