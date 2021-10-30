{-# OPTIONS_GHC -Wall -Wno-orphans #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
module TestBDD (bddTestGroup) where

import Control.Monad
import qualified Data.IntMap as IntMap
import Data.IntSet (IntSet)
import qualified Data.IntSet as IntSet
import Data.List
import Data.Proxy
import Test.QuickCheck.Function (apply)
import Test.Tasty
import Test.Tasty.HUnit
import Test.Tasty.QuickCheck
import Test.Tasty.TH

import Data.DecisionDiagram.BDD (BDD (..), ItemOrder (..), withDefaultOrder)
import qualified Data.DecisionDiagram.BDD as BDD

-- ------------------------------------------------------------------------

instance BDD.ItemOrder a => Arbitrary (BDD a) where
  arbitrary = arbitraryBDDOver =<< liftM IntSet.fromList arbitrary

  shrink (BDD.F) = []
  shrink (BDD.T) = []
  shrink (BDD.Branch x p0 p1) =
    [p0, p1]
    ++
    [ BDD.Branch x p0' p1'
    | (p0', p1') <- shrink (p0, p1), p0' /= p1'
    ]

arbitraryBDDOver :: forall a. BDD.ItemOrder a => IntSet -> Gen (BDD a)
arbitraryBDDOver xs = do
  let f vs n = oneof $
        [ return BDD.true
        , return BDD.false
        ]
        ++
        [ do v <- elements vs
             let vs' = dropWhile (\v' -> compareItem (Proxy :: Proxy a) v' v  /= GT) vs
             lo <- f vs' (n `div` 2)
             hi <- f vs' (n `div` 2) `suchThat` (/= lo)
             return (BDD.Branch v lo hi)
        | n > 0, not (null vs)
        ]
  sized $ f (sortBy (BDD.compareItem (Proxy :: Proxy a)) $ IntSet.toList xs)

-- ------------------------------------------------------------------------
-- conjunction
-- ------------------------------------------------------------------------

prop_and_unitL :: Property
prop_and_unitL =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (BDD.true BDD..&&. a) === a

prop_and_unitR :: Property
prop_and_unitR =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (a BDD..&&. BDD.true) === a

prop_and_falseL :: Property
prop_and_falseL =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (BDD.false BDD..&&. a) === BDD.false

prop_and_falseR :: Property
prop_and_falseR =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (a BDD..&&. BDD.false) === BDD.false

prop_and_comm :: Property
prop_and_comm =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      (a BDD..&&. b) === (b BDD..&&. a)

prop_and_assoc :: Property
prop_and_assoc =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b, c) ->
      (a BDD..&&. (b BDD..&&. c)) === ((a BDD..&&. b) BDD..&&. c)

prop_and_idempotent :: Property
prop_and_idempotent =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (a BDD..&&. a) === a

-- ------------------------------------------------------------------------
-- disjunction
-- ------------------------------------------------------------------------

prop_or_unitL :: Property
prop_or_unitL =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (BDD.false BDD..||. a) === a

prop_or_unitR :: Property
prop_or_unitR =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (a BDD..||. BDD.false) === a

prop_or_trueL :: Property
prop_or_trueL =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (BDD.true BDD..||. a) === BDD.true

prop_or_trueR :: Property
prop_or_trueR =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (a BDD..||. BDD.true) === BDD.true

prop_or_comm :: Property
prop_or_comm =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      (a BDD..||. b) === (b BDD..||. a)

prop_or_assoc :: Property
prop_or_assoc =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b, c) ->
      (a BDD..||. (b BDD..||. c)) === ((a BDD..||. b) BDD..||. c)

prop_or_idempotent :: Property
prop_or_idempotent =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (a BDD..||. a) === a

-- ------------------------------------------------------------------------
-- distributivity
-- ------------------------------------------------------------------------

prop_dist_1 :: Property
prop_dist_1 =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b, c) ->
      (a BDD..&&. (b BDD..||. c)) === ((a BDD..&&. b) BDD..||. (a BDD..&&. c))

prop_dist_2 :: Property
prop_dist_2 =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b, c) ->
      (a BDD..||. (b BDD..&&. c)) === ((a BDD..||. b) BDD..&&. (a BDD..||. c))

prop_absorption_1 :: Property
prop_absorption_1 =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      (a BDD..&&. (a BDD..||. b)) === a

prop_absorption_2 :: Property
prop_absorption_2 =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      (a BDD..||. (a BDD..&&. b)) === a

-- ------------------------------------------------------------------------
-- negation
-- ------------------------------------------------------------------------

prop_double_negation :: Property
prop_double_negation =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      BDD.notB (BDD.notB a) === a

prop_and_complement :: Property
prop_and_complement =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (a BDD..&&. BDD.notB a) === BDD.false

prop_or_complement :: Property
prop_or_complement =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (a BDD..||. BDD.notB a) === BDD.true

prop_de_morgan_1 :: Property
prop_de_morgan_1 =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      BDD.notB (a BDD..||. b) === (BDD.notB a BDD..&&. BDD.notB b)

prop_de_morgan_2 :: Property
prop_de_morgan_2 =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      BDD.notB (a BDD..&&. b) === (BDD.notB a BDD..||. BDD.notB b)

-- ------------------------------------------------------------------------

case_support_false :: Assertion
case_support_false = BDD.support BDD.false @?= IntSet.empty

case_support_true :: Assertion
case_support_true = BDD.support BDD.true @?= IntSet.empty

prop_support_var :: Property
prop_support_var =
  forAll arbitrary $ \x ->
    BDD.support (BDD.var x) === IntSet.singleton x

prop_support_not :: Property
prop_support_not =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      let lhs = BDD.support a
          rhs = BDD.support (BDD.notB a)
       in lhs === rhs

prop_support_and :: Property
prop_support_and =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      let lhs = BDD.support (a BDD..&&. b)
          rhs = BDD.support a `IntSet.union` BDD.support b
       in counterexample (show (lhs, rhs)) $ lhs `IntSet.isSubsetOf` rhs

prop_support_or :: Property
prop_support_or =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      let lhs = BDD.support (a BDD..||. b)
          rhs = BDD.support a `IntSet.union` BDD.support b
       in counterexample (show (lhs, rhs)) $ lhs `IntSet.isSubsetOf` rhs

-- ------------------------------------------------------------------------

prop_evaluate_var :: Property
prop_evaluate_var =
 forAll arbitrary $ \(f' :: Fun Int Bool) ->
   let f = apply f'
    in withDefaultOrder $ \(_ :: Proxy o) ->
         forAll arbitrary $ \x ->
           BDD.evaluate f (BDD.var x :: BDD o) === f x

prop_evaluate_not :: Property
prop_evaluate_not =
 forAll arbitrary $ \(f' :: Fun Int Bool) ->
   let f = apply f'
    in withDefaultOrder $ \(_ :: Proxy o) ->
         forAll arbitrary $ \(a :: BDD o) ->
           BDD.evaluate f (BDD.notB a) === not (BDD.evaluate f a)

prop_evaluate_and :: Property
prop_evaluate_and =
 forAll arbitrary $ \(f' :: Fun Int Bool) ->
   let f = apply f'
    in withDefaultOrder $ \(_ :: Proxy o) ->
         forAll arbitrary $ \(a :: BDD o, b) ->
           BDD.evaluate f (a BDD..&&. b) === (BDD.evaluate f a && BDD.evaluate f b)

prop_evaluate_or :: Property
prop_evaluate_or =
 forAll arbitrary $ \(f' :: Fun Int Bool) ->
   let f = apply f'
    in withDefaultOrder $ \(_ :: Proxy o) ->
         forAll arbitrary $ \(a :: BDD o, b) ->
           BDD.evaluate f (a BDD..||. b) === (BDD.evaluate f a || BDD.evaluate f b)

-- ------------------------------------------------------------------------

prop_restrict :: Property
prop_restrict =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \x ->
        let b = (BDD.var x BDD..&&. BDD.restrict x True a) BDD..||.
                (BDD.notB (BDD.var x) BDD..&&. BDD.restrict x False a)
         in a === b

prop_restrict_idempotent :: Property
prop_restrict_idempotent =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \(x, val) ->
        let b = BDD.restrict x val a
            c = BDD.restrict x val b
         in counterexample (show (b, c)) $ b === c

prop_restrict_not :: Property
prop_restrict_not =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \(x, val) ->
        BDD.restrict x val (BDD.notB a) === BDD.notB (BDD.restrict x val a)

prop_restrict_and :: Property
prop_restrict_and =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      forAll arbitrary $ \(x, val) ->
        BDD.restrict x val (a BDD..&&. b) === (BDD.restrict x val a BDD..&&. BDD.restrict x val b)

prop_restrict_or :: Property
prop_restrict_or =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      forAll arbitrary $ \(x, val) ->
        BDD.restrict x val (a BDD..||. b) === (BDD.restrict x val a BDD..||. BDD.restrict x val b)

prop_restrict_var :: Property
prop_restrict_var =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \x ->
      let a :: BDD o
          a = BDD.var x
       in (BDD.restrict x True a === BDD.true) .&&.
          (BDD.restrict x False a === BDD.false)

prop_restrict_support :: Property
prop_restrict_support =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \(x, val) ->
        let b = BDD.restrict x val a
            xs = BDD.support b
         in counterexample (show b) $
            counterexample (show xs) $
              x `IntSet.notMember` xs

-- ------------------------------------------------------------------------

prop_restrictSet_empty :: Property
prop_restrictSet_empty =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      BDD.restrictSet IntMap.empty a === a

prop_restrictSet_singleton :: Property
prop_restrictSet_singleton =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \(x, val) ->
        BDD.restrict x val a === BDD.restrictSet (IntMap.singleton x val) a

prop_restrictSet_union :: Property
prop_restrictSet_union =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \(val1, val2) ->
        and (IntMap.intersectionWith (==) val1 val2)
        ==>
        (BDD.restrictSet val2 (BDD.restrictSet val1 a) === BDD.restrictSet (val1 `IntMap.union` val2) a)

prop_restrictSet_idempotent :: Property
prop_restrictSet_idempotent =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \val ->
        let b = BDD.restrictSet val a
            c = BDD.restrictSet val b
         in counterexample (show (b, c)) $ b === c

prop_restrictSet_not :: Property
prop_restrictSet_not =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \val ->
        BDD.restrictSet val (BDD.notB a) === BDD.notB (BDD.restrictSet val a)

prop_restrictSet_and :: Property
prop_restrictSet_and =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      forAll arbitrary $ \val ->
        BDD.restrictSet val (a BDD..&&. b) === (BDD.restrictSet val a BDD..&&. BDD.restrictSet val b)

prop_restrictSet_or :: Property
prop_restrictSet_or =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      forAll arbitrary $ \val ->
        BDD.restrictSet val (a BDD..||. b) === (BDD.restrictSet val a BDD..||. BDD.restrictSet val b)

-- ------------------------------------------------------------------------

prop_restrictLaw_true :: Property
prop_restrictLaw_true =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      BDD.restrictLaw BDD.true a === a

prop_restrictLaw_self :: Property
prop_restrictLaw_self =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (a /= BDD.false) ==> BDD.restrictLaw a a === BDD.true

prop_restrictLaw_not_self :: Property
prop_restrictLaw_not_self =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      (a /= BDD.true) ==> BDD.restrictLaw (BDD.notB a) a === BDD.false

prop_restrictLaw_restrictSet :: Property
prop_restrictLaw_restrictSet =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \val ->
        let b = BDD.andB [if v then BDD.var x else BDD.notB (BDD.var x) | (x,v) <- IntMap.toList val]
         in BDD.restrictLaw b a === BDD.restrictSet val a

-- prop_restrictLaw_and_condition :: Property
-- prop_restrictLaw_and_condition =
--   withDefaultOrder $ \(_ :: Proxy o) ->
--     forAll arbitrary $ \(a :: BDD o) ->
--       forAll arbitrary $ \(val1, val2) ->
--         let val = val1 BDD..&&. val2
--          in counterexample (show val) $
--               (val /= BDD.false)
--               ==>
--               (BDD.restrictLaw val a === BDD.restrictLaw val2 (BDD.restrictLaw val1 a))

-- counterexample to above prop_restrictLaw_and_condition
case_restrictLaw_case_1 :: Assertion
case_restrictLaw_case_1 = do
  -- BDD.restrictLaw val a @?= BDD.restrictLaw val2 (BDD.restrictLaw val1 a)
  BDD.restrictLaw val a @?= BDD.Branch 2 BDD.F BDD.T
  BDD.restrictLaw val2 (BDD.restrictLaw val1 a) @?= BDD.Branch 1 BDD.T (Branch 2 BDD.F BDD.T)
  where
    a :: BDD BDD.DefaultOrder
    a = Branch 2 BDD.F BDD.T -- x2
    val1 = BDD.Branch 1 BDD.F BDD.T -- x1
    val2 = BDD.Branch 1 (BDD.Branch 2 BDD.F BDD.T) BDD.T -- x1 ∨ x2
    val = val1 BDD..&&. val2 -- x1

prop_restrictLaw_or_condition :: Property
prop_restrictLaw_or_condition =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \(val1, val2) ->
        let val = val1 BDD..||. val2
         in counterexample (show val) $
              (val BDD..&&. BDD.restrictLaw val a) === (val1 BDD..&&. BDD.restrictLaw val1 a BDD..||. val2 BDD..&&. BDD.restrictLaw val2 a)

prop_restrictLaw_idempotent :: Property
prop_restrictLaw_idempotent =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll arbitrary $ \val ->
        let b = BDD.restrictLaw val a
            c = BDD.restrictLaw val b
         in counterexample (show (b, c)) $ b === c

prop_restrictLaw_not :: Property
prop_restrictLaw_not =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o) ->
      forAll (arbitrary `suchThat` (/= BDD.false)) $ \val ->
        BDD.restrictLaw val (BDD.notB a) === BDD.notB (BDD.restrictLaw val a)

prop_restrictLaw_and :: Property
prop_restrictLaw_and =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      forAll (arbitrary `suchThat` (/= BDD.false)) $ \val ->
        BDD.restrictLaw val (a BDD..&&. b) === (BDD.restrictLaw val a BDD..&&. BDD.restrictLaw val b)

prop_restrictLaw_or :: Property
prop_restrictLaw_or =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(a :: BDD o, b) ->
      forAll (arbitrary `suchThat` (/= BDD.false)) $ \val ->
        BDD.restrictLaw val (a BDD..||. b) === (BDD.restrictLaw val a BDD..||. BDD.restrictLaw val b)

-- ------------------------------------------------------------------------

prop_subst_restrict_constant :: Property
prop_subst_restrict_constant =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(m :: BDD o) ->
    forAll arbitrary $ \x ->
    forAll arbitrary $ \val ->
      BDD.subst x (if val then BDD.true else BDD.false) m === BDD.restrict x val m

prop_subst_restrict :: Property
prop_subst_restrict =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(m :: BDD o) ->
    forAll arbitrary $ \x ->
    forAll arbitrary $ \(n :: BDD o) ->
      BDD.subst x n m === ((n BDD..&&. BDD.restrict x True m) BDD..||. (BDD.notB n BDD..&&. BDD.restrict x False m))

prop_subst_same_var :: Property
prop_subst_same_var =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(m :: BDD o) ->
    forAll arbitrary $ \x ->
      BDD.subst x (BDD.var x) m === m

prop_subst_not_occured :: Property
prop_subst_not_occured =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(m :: BDD o) ->
    forAll (arbitrary `suchThat` (\x -> x `IntSet.notMember` (BDD.support m))) $ \x ->
    forAll arbitrary $ \(n :: BDD o) ->
      BDD.subst x n m === m

-- If x1≠x2 and x1∉FV(M2) then M[x1 ↦ M1][x2 ↦ M2] = M[x2 ↦ M2][x1 ↦ M1[x2 ↦ M2]].
prop_subst_dist :: Property
prop_subst_dist =
  withDefaultOrder $ \(_ :: Proxy o) ->
    forAll arbitrary $ \(x1, m1) ->
    forAll ((,) <$> (arbitrary `suchThat` (/= x1)) <*> (arbitrary `suchThat` (\m2 -> x1 `IntSet.notMember` BDD.support m2))) $ \(x2, m2) ->
    forAll arbitrary $ \(m :: BDD o) ->
      BDD.subst x2 m2 (BDD.subst x1 m1 m) === BDD.subst x1 (BDD.subst x2 m2 m1) (BDD.subst x2 m2 m)

-- ------------------------------------------------------------------------

bddTestGroup :: TestTree
bddTestGroup = $(testGroupGenerator)
