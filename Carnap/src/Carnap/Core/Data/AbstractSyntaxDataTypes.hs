{-#LANGUAGE TypeFamilies, UndecidableInstances, FlexibleInstances, MultiParamTypeClasses, AllowAmbiguousTypes, GADTs, KindSignatures, DataKinds, PolyKinds, TypeOperators, ViewPatterns, PatternSynonyms, RankNTypes, FlexibleContexts #-}

module Carnap.Core.Data.AbstractSyntaxDataTypes(
  Modelable, Evaluable, Term(Term), Form(Form), CopulaSchema,
  satisfies, eval, schematize, lift, lift1, lift2, canonical,
  appSchema, lamSchema, liftSchema,
  Copula((:$:), Lam), (:|:)(FLeft, FRight), Quantifiers(Bind),Abstractors(Abstract),Applicators(Apply),
  Nat(Zero, Succ), Fix(Fx), Vec(VNil, VCons), Arity(AZero, ASucc),
  Predicate(Predicate), Connective(Connective), Function(Function),
  Subnective(Subnective),CanonicalForm, Schematizable, FixLang,
  pattern AOne, pattern ATwo , pattern LLam, pattern (:!$:)
) where

import Carnap.Core.Util
import Control.Lens
import Control.Lens.Plated

--This module attempts to provide abstract syntax types that would cover
--a wide variety of languages


--1. Abstract typeclasses
--------------------------------------------------------

--class of terms that we can compute a fregean denotation for, relative to
--a model or assignment of some sort.
-- | a type is modelable if it can be modeled. these are generally parts from
-- | which LModelable types are built up
class Modelable m f where
    satisfies :: m -> f a -> a

-- | Just like modelable but where a default model is picked for us
-- | this is useful as a convience and when there is one cononical model
-- | such as in the case of peano arithmetic
class Evaluable f where
    eval :: f a -> a

class Liftable f where
    lift :: a -> f a

class Schematizable f where
    schematize :: f a -> [String] -> String

class CopulaSchema lang where
    appSchema :: lang (t -> t') -> lang t -> [String] -> String
    liftSchema :: Copula lang t -> [String] -> String
    lamSchema :: (lang t -> lang t') -> [String] -> String

class CanonicalForm a where
    canonical :: a -> a

lift1 :: (Evaluable f, Liftable f) => (a -> b) -> (f a -> f b)
lift1 f = lift . f . eval

lift2 :: (Evaluable f, Liftable f) => (a -> b -> c) -> (f a -> f b -> f c)
lift2 f fa fb = lift (f (eval fa) (eval fb))

--------------------------------------------------------
--2. Abstract Types
--------------------------------------------------------

--Here are some types for abstract syntax. The basic proposal
--is that we only define how terms of different types connect
--and let the user define all the connections independently of
--of their subparts. In some sense they just define the type
--and the type system figures out how they can go together

--We use the idea of a semantic value to indicate approximately a Fregean
--sense, or intension: approximately a function from models to Fregean
--denotations in those models

--------------------------------------------------------
--2.1 Abstract Terms
--------------------------------------------------------

-- | this is the type that describes how things are connected
-- | Things are connected either by application or by
-- | a lambda abstraction. The 'lang' parameter gets fixed to
-- | form a fully usable type
--
-- @
--    Fix (Copula :|: Copula :|: (Predicate BasicProp :|: Connective BasicConn))
-- @
data Copula lang t where
    (:$:) :: lang (t -> t') -> lang t -> Copula lang t'
    Lam :: (lang t -> lang t') -> Copula lang (t -> t')
    Lift :: t -> Copula lang t

-- | this is type acts a disjoint sum/union of two functors
-- | it carries though the phantom type as well
data (:|:) :: (k -> k' -> *) -> (k -> k' -> *) -> k -> k' -> * where
    FLeft :: f x idx -> (f :|: g) x idx
    FRight :: g x idx -> (f :|: g) x idx

-- | This type fixes the first argument of a functor and carries though a
-- | phantom type
-- | note that only certian kinds of functors even have a kind
-- | such that the first argument is fixable
newtype Fix f idx = Fx (f (Fix f) idx)

type FixLang f = Fix (Copula :|: f)

pattern LLam f = Fx (FLeft (Lam f))
pattern (:!$:) f x = Fx (FLeft (f :$: x))

data Quantifiers :: (* -> *) -> (* -> *) -> * -> * where
    Bind :: quant ((t a -> f b) -> f b) -> Quantifiers quant lang ((t a -> f b) -> f b)

data Abstractors :: (* -> *) -> (* -> *) -> * -> * where
    Abstract :: abs ((t a -> t b) -> t (a -> b)) -> Abstractors abs lang ((t a -> t b) -> t (a -> b))

data Applicators :: (* -> *) -> (* -> *) -> * -> * where
    Apply :: app (t (a -> b) -> t a -> t b) -> Applicators app lang (t (a -> b) -> t a -> t b)

data Term a = Term a
    deriving(Eq, Ord, Show)
data Form a = Form a
    deriving(Eq, Ord, Show)

instance Evaluable Term where
    eval (Term x) = x

instance Evaluable Form where
    eval (Form x) = x

instance Liftable Term where
    lift = Term

instance Liftable Form where
    lift = Form

-- | think of this as a type constraint. the lang type, model type, and number
-- | must all match up for this type to be inhabited
-- | this lets us do neat type safty things
data Arity :: * -> * -> Nat -> * -> * where
    AZero :: Arity arg ret Zero ret
    ASucc :: Arity arg ret n ret' -> Arity arg ret (Succ n) (arg -> ret')

pattern AOne = (ASucc AZero)
pattern ATwo = (ASucc (ASucc AZero))

data Predicate :: (* -> *) -> (* -> *) -> * -> * where
    Predicate :: pred t -> Arity a b n t -> Predicate pred lang t

data Connective :: (* -> *) -> (* -> *) -> * -> * where
    Connective :: con t -> Arity a b n t -> Connective con lang t

data Function :: (* -> *) -> (* -> *) -> * -> * where
    Function :: func t -> Arity a b n t -> Function func lang t

data Subnective :: (* -> *) -> (* -> *) -> * -> * where
    Subnective :: sub t -> Arity a b n t -> Subnective sub lang t

--data Quote :: (* -> *) -> * -> *
    --Quote :: (lang )
--------------------------------------------------------
--3. Schematizable, Show, and Eq
--------------------------------------------------------

instance (Schematizable (f a), Schematizable (g a)) => Schematizable ((f :|: g) a) where
        schematize (FLeft a) = schematize a
        schematize (FRight a) = schematize a

instance Schematizable (f (Fix f)) => Schematizable (Fix f) where
    schematize (Fx a) = schematize a

instance Schematizable quant => Schematizable (Quantifiers quant lang) where
        schematize (Bind q) arg = schematize q arg --here I assume 'q' stores the users varible name

instance Schematizable abs => Schematizable (Abstractors abs lang) where
        schematize (Abstract a) arg = schematize a arg --here I assume 'q' stores the users varible name

instance Schematizable pred => Schematizable (Predicate pred lang) where
        schematize (Predicate p _) = schematize p

instance Schematizable con => Schematizable (Connective con lang) where
        schematize (Connective c _) = schematize c

instance Schematizable func => Schematizable (Function func lang) where
        schematize (Function f _) = schematize f

instance Schematizable app => Schematizable (Applicators app lang) where
        schematize (Apply f) = schematize f

instance Schematizable sub => Schematizable (Subnective sub lang) where
        schematize (Subnective s _) = schematize s

instance CopulaSchema lang => Schematizable (Copula lang) where
        schematize (f :$: x) e = appSchema f x e
        schematize (Lam f)   e = lamSchema f e
        schematize x         e = liftSchema x e

instance (Schematizable (f a), Schematizable (g a)) => Show ((f :|: g) a b) where
        show (FLeft a) = schematize a []
        show (FRight a) = schematize a []

instance Schematizable (f (Fix f)) => Show (Fix f idx) where
        show (Fx a) = schematize a []

instance Schematizable quant => Show (Quantifiers quant lang a) where
        show x = schematize x []

instance Schematizable pred => Show (Predicate pred lang a) where
        show x = schematize x []

instance Schematizable con => Show (Connective con lang a) where
        show x = schematize x []

instance Schematizable func => Show (Function func lang a) where
        show x = schematize x []

instance Schematizable sub => Show (Subnective sub lang a) where
        show x = schematize x []

--instance -# OVERLAPPING #- Schematizable ((Copula :|: f1) a) => Eq ((Copula :|: f1) a b) where
        --x == y = show x == show y

instance Schematizable quant => Eq (Quantifiers quant lang a) where
        x == y = show x == show y

instance Schematizable pred => Eq (Predicate pred lang a) where
        x == y = show x == show y

instance Schematizable con => Eq (Connective con lang a) where
        x == y = show x == show y

instance Schematizable func => Eq (Function func lang a) where
        x == y = show x == show y

instance Schematizable sub => Eq (Subnective sub lang a) where
        x == y = show x == show y

instance (Schematizable (f a), Schematizable (g a)) => Eq ((f :|: g) a b) where
        x == y = show x == show y

instance  (CanonicalForm (FixLang f a), Show (FixLang f a)) => Eq (FixLang f a) where
        x == y = show (canonical x) == show (canonical y)

--}
--------------------------------------------------------
--4. Evaluation and Modelable
--------------------------------------------------------

instance Evaluable quant => Evaluable (Quantifiers quant lang) where
    eval (Bind q) = eval q

instance Evaluable abs => Evaluable (Abstractors abs lang) where
    eval (Abstract a) = eval a

instance Evaluable pred => Evaluable (Predicate pred lang) where
    eval (Predicate p a) = eval p

instance Evaluable con => Evaluable (Connective con lang) where
    eval (Connective p a) = eval p

instance Evaluable func => Evaluable (Function func lang) where
    eval (Function p _) = eval p

instance Evaluable app => Evaluable (Applicators app lang) where
    eval (Apply f) = eval f

instance Evaluable sub => Evaluable (Subnective sub lang) where
    eval (Subnective p a) = eval p

instance (Evaluable (f lang), Evaluable (g lang)) => Evaluable ((f :|: g) lang) where
    eval (FLeft p) = eval p
    eval (FRight p) = eval p

instance (Evaluable (f (Fix f))) => Evaluable (Fix f) where
    eval (Fx a) = eval a

instance Liftable (Fix (Copula :|: a)) where
    lift a = Fx $ FLeft (Lift a)

instance (Liftable lang, Evaluable lang) => Evaluable (Copula lang) where
    eval (f :$: x) = eval f (eval x)
    eval (Lam f)   = \t -> eval $ f (lift t)
    eval (Lift t)  = t

instance Modelable m quant => Modelable m (Quantifiers quant lang) where
    satisfies m (Bind q) = satisfies m q

instance Modelable m abs => Modelable m (Abstractors abs lang) where
    satisfies m (Abstract a) = satisfies m a

instance Modelable m pred => Modelable  m (Predicate pred lang) where
    satisfies m (Predicate p a) = satisfies m p

instance Modelable m con => Modelable m (Connective con lang) where
    satisfies m (Connective p a) = satisfies m p

instance Modelable m func => Modelable m (Function func lang) where
    satisfies m (Function p _) = satisfies m p

instance Modelable m app => Modelable m (Applicators app lang) where
    satisfies m (Apply p) = satisfies m p

instance Modelable m sub => Modelable m (Subnective sub lang) where
    satisfies m (Subnective p a) = satisfies m p

instance (Modelable m (f lang), Modelable m (g lang)) => Modelable m ((f :|: g) lang) where
    satisfies m (FLeft p) = satisfies m p
    satisfies m (FRight p) = satisfies m p

instance (Modelable m (f (Fix f))) => Modelable m (Fix f) where
    satisfies m (Fx a) = satisfies m a

instance (Liftable lang, Modelable m lang) => Modelable m (Copula lang) where
    satisfies m (f :$: x) = satisfies m f (satisfies m x)
    satisfies m (Lam f) = \t -> satisfies m $ f (lift t)
    satisfies m (Lift t) = t
