{-# LANGUAGE UnicodeSyntax, DataKinds, TypeOperators, KindSignatures,
             TypeInType, GADTs, MultiParamTypeClasses, FunctionalDependencies,
             TypeFamilies, AllowAmbiguousTypes, FlexibleInstances,
             UndecidableInstances, InstanceSigs, TypeApplications, ScopedTypeVariables,
             EmptyCase
#-}

module Context where

import Data.Kind
import Data.Constraint

import Types

-- Fresh variable ------------------------------------------

type family FreshN (g :: NCtx sig) :: Ident where
  FreshN ('End t)            = 'S 'Z
  FreshN ('Cons 'Unused g)   = 'Z
  FreshN ('Cons ('Used s) g) = 'S (FreshN g)

type family Fresh (g::Ctx sig) :: Ident where
  Fresh 'Empty = 'Z
  Fresh ('N g) = FreshN g

type family FreshN2 g :: Ident where
  FreshN2 ('End t)           = 'S ('S 'Z)
  FreshN2 ('Cons 'Unused g)   = 'S (FreshN g)
  FreshN2 ('Cons ('Used s) g) = 'S (FreshN2 g)


type family Fresh2 (g::Ctx sig) :: Ident where
  Fresh2 'Empty = 'S 'Z
  Fresh2 ('N g) = FreshN2 g


-- Disjoint Identifiers --------------------------------

data Disjoint :: Ident -> Ident -> * where
  DisjointZS :: Disjoint 'Z ('S n) 
  DisjointSZ :: Disjoint ('S n) 'Z
  DisjointSS :: Disjoint m n -> Disjoint ('S m) ('S n)

-- Shift -----------------------------------------------------

-- data ShiftN :: Ident -> NCtx -> NCtx -> * where
--   ShiftHere  :: ShiftN 'Z g ('Cons 'Unused g)
--   ShiftLater :: ShiftN x g g' -> ShiftN ('S x) ('Cons u g) ('Cons u' g)

-- data Shift :: Nat -> Ctx -> Ctx -> * where
--   Shift :: ShiftN x g g' -> Shift x ('N g) ('N g')


-- Add To Context ----------------------------------------------

-- changed defn of Add
data AddNCtxN :: Ident -> LType sig -> NCtx sig -> NCtx sig -> * where
  AddHere  :: SNCtx g -> AddNCtxN 'Z s ('Cons 'Unused g) ('Cons ('Used s) g)
  AddEnd   :: SingletonNCtx x s g  -> AddNCtxN ('S x) s ('End t) ('Cons ('Used t) g)
  AddLater :: SUsage u -> AddNCtxN x s g g'    -> AddNCtxN ('S x) s ('Cons u g) ('Cons u g')


data AddCtxN :: Ident -> LType sig -> Ctx sig -> NCtx sig -> * where
  AddS       :: SingletonNCtx x s g -> AddCtxN x s 'Empty g
--  AddEHere   :: AddCtxN 'Z s 'Empty ('End s)
--  AddELater  :: AddCtxN x s 'Empty g  -> AddCtxN ('S x) s 'Empty ('Cons 'Unused g)
  AddNN      :: AddNCtxN x s g g' -> AddCtxN x s ('N g) g'

data AddCtx  :: Nat -> LType sig -> Ctx sig -> Ctx sig -> * where
  AddN :: AddCtxN x s g g' -> AddCtx x s g ('N g')


-- Singleton Context ------------------------------------------

data SingletonNCtx :: Nat -> LType sig -> NCtx sig -> * where
  AddHereS  :: SingletonNCtx 'Z s ('End s)
  AddLaterS :: SingletonNCtx x s g -> SingletonNCtx ('S x) s ('Cons 'Unused g)

data SingletonCtx :: Nat -> LType sig -> Ctx sig -> * where
  SingN :: SingletonNCtx x s g -> SingletonCtx x s ('N g)


-- Merge ----------------------------------------------------

data MergeU :: Usage sig -> Usage sig -> Usage sig -> * where
  MergeUn :: MergeU 'Unused   'Unused   'Unused
  MergeUL :: MergeU ('Used s) 'Unused   ('Used s)
  MergeUR :: MergeU 'Unused   ('Used s) ('Used s)

data Merge :: Ctx sig -> Ctx sig -> Ctx sig -> * where
  MergeE  :: Merge 'Empty 'Empty 'Empty
  MergeEL :: SNCtx g -> Merge 'Empty ('N g) ('N g)
  MergeER :: SNCtx g -> Merge ('N g) 'Empty ('N g)
  MergeN  :: MergeN g1 g2 g3 -> Merge ('N g1) ('N g2) ('N g3)

data MergeN :: NCtx sig -> NCtx sig -> NCtx sig -> * where
  MergeEndL :: SNCtx g2 -> MergeN ('End s) ('Cons 'Unused g2) ('Cons ('Used s) g2)
  MergeEndR :: SNCtx g1 -> MergeN ('Cons 'Unused g1) ('End s) ('Cons ('Used s) g1)
  MergeCons :: MergeU u1 u2 u3 -> MergeN g1 g2 g3 
            -> MergeN ('Cons u1 g1) ('Cons u2 g2) ('Cons u3 g3)


-- In -------------------------------

data InN :: Nat -> LType sig -> NCtx sig -> * where
  InEnd   :: InN 'Z s ('End s)
  InHere  :: SNCtx g    -> InN 'Z s ('Cons ('Used s) g)
  InLater :: SUsage u   -> InN x s g  -> InN ('S x) s ('Cons u g)

data In :: Nat -> LType sig -> Ctx sig -> * where
  In :: InN x s g -> In x s ('N g)

-- Div -----------------------------------------------
 
type family DivF g' g :: Ctx sig where
  DivF g' 'Empty = g'
  DivF ('N g') ('N g) = DivNF g' g

type family DivNF g' g :: Ctx sig where
  DivNF ('End s)             ('End s) = 'Empty
  DivNF ('Cons ('Used s) g') ('End s) = 'N ('Cons 'Unused g')
  DivNF ('Cons ('Used s) g') ('Cons ('Used s) g) = ConsN 'Unused (DivNF g' g)
  DivNF ('Cons u g')         ('Cons 'Unused g)   = ConsN u (DivNF g' g)


data Div :: Ctx sig -> Ctx sig -> Ctx sig -> * where
  DivEmpty :: SCtx g -> Div g 'Empty g
  DivN     :: DivN g1 g2 g3 -> Div ('N g1) ('N g2) g3

data DivN       :: NCtx sig -> NCtx sig -> Ctx sig -> * where
  DivEndEnd     :: DivN ('End s) ('End s) 'Empty
  DivConsEnd    :: SNCtx g -> DivN ('Cons ('Used s) g) ('End s) ('N ('Cons 'Unused g))
  DivConsCons   :: DivN g1 g2 g3 
                -> MergeU u3 u2 u1
                -> DivN ('Cons u1 g1) ('Cons u2 g2) (ConsN u3 g3)

-- Shift ----------------------------------------

data ShiftCtx :: Usage sig -> Ctx sig -> Ctx sig -> * where
  ShiftEmptyUsed   :: ShiftCtx ('Used s) 'Empty ('N (End s))
  ShiftEmptyUnused :: ShiftCtx 'Unused 'Empty 'Empty
  ShiftN           :: ShiftCtx u ('N g) ('N ('Cons u g))


-- Relation between In and Shift

-- type family InShift x n :: Nat where
--   InShift ('S x) 'Z     = x
--   InShift 'Z     ('S n) = 'Z
--   InShift ('S x) ('S n) = 'S (InShift x n)


