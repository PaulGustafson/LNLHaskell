{-# LANGUAGE UnicodeSyntax, DataKinds, TypeOperators, KindSignatures,
             TypeInType, GADTs, MultiParamTypeClasses, FunctionalDependencies,
             TypeFamilies, AllowAmbiguousTypes, FlexibleInstances,
             UndecidableInstances, InstanceSigs, TypeApplications, 
             ScopedTypeVariables, FlexibleContexts,
             EmptyCase, RankNTypes, TypeFamilyDependencies
#-}

module Interface where

import Data.Kind
import Data.Constraint
import Data.Proxy
--import Control.Category

import Types
import Context
import Proofs
import Classes
import Lang
import Subst
import Eval

type Var x s = SIdent x

var :: Var x s -> LExp sig (Singleton x s) s
var x = Var $ singSing x



λ :: forall sig s t g g'. CAddCtx (Fresh g) s g g'
  => (Var (Fresh g) s -> LExp sig g' t)
  -> LExp sig g (s ⊸ t)
λ f = Abs pfA (f x) where
  pfA :: AddCtx (Fresh g) s g g'
  pfA  = addCtx
  x   :: SIdent (Fresh g)
  x    = addToSIdent pfA

app :: CMerge g1 g2 g3 
    => LExp sig g1 (s ⊸ t)
    -> LExp sig g2 s
    -> LExp sig g3 t
e1 `app` e2 = App merge e1 e2


letin :: CMerge g1 g2 g
      => LExp sig g1 s
      -> LExp sig g2 (s ⊸ t)
      -> LExp sig g t
letin e f = f `app` e

-- Categories ----------------------------

--newtype LArrow (dom :: Dom sig) (s :: LType sig) (t :: LType sig) = LArrow (LExp dom 'Empty (s ⊸ t))

--instance Category (LArrow dom) where
--  id    = LArrow $ λ var
--  LArrow g . LArrow f = LArrow Prelude.. λ $ \x -> g `app` (f `app` var x)

-- DEFINING DOMAINS ---------------------------------

-- Abstraction and Application ----------------------


{-
data LolliSig ty where
  LolliSig :: ty -> ty -> LolliSig ty

class HasLolli sig where
  type (⊸) (s :: LType sig) (t :: LType sig) :: LType sig

infixr 0 ⊸

instance CInList LolliSig (SigType sig) => HasLolli sig where
  type s ⊸ t = 'Sig PfInList ('LolliSig s t)

data LolliLExp :: ExpDom sig where
  Abs :: AddCtx x s g g'
      -> exp g' t
      -> LolliLExp exp g (s ⊸ t)
  App :: Merge g1 g2 g
      -> exp g1 (s ⊸ t)
      -> exp g2 s
      -> LolliLExp exp g t

data LolliLVal :: ValDom sig where
  VAbs :: AddCtx x s g g'
       -> 
-}


-- One ---------------------------------------
-- GOAL: have types that don't have to be indexed by the signature.

data OneSig ty where
  OneSig :: OneSig ty

type One = ('Sig (InSig OneSig sig) 'OneSig :: LType sig)

class (Monad (SigEffect sig),CInSig OneSig sig) => HasOneSig sig 
instance (Monad (SigEffect sig),CInSig OneSig sig) => HasOneSig sig 

data OneExp :: forall sig. ExpDom sig where
  Unit :: forall sig (exp :: Ctx sig -> LType sig -> *).
          HasOneSig sig => OneExp exp 'Empty One
  LetUnit :: forall sig (exp :: Ctx sig -> LType sig -> *) 
                   (g :: Ctx sig) (g1 :: Ctx sig) (g2 :: Ctx sig) (t :: LType sig).
            HasOneSig sig
         => Merge g1 g2 g -> exp g1 One -> exp g2 t -> OneExp exp g t

data OneVal :: forall sig. ValDom sig where
  VUnit :: forall sig (val :: LType sig -> *).
           HasOneSig sig => OneVal val One

proxyOne :: (Proxy OneExp, Proxy OneVal)
proxyOne = (Proxy,Proxy)

unit :: (HasOneSig sig, InDom sig OneExp OneVal dom)
     => LExp dom 'Empty One
unit = Dom proxyOne Unit
letUnit :: (HasOneSig sig, InDom sig OneExp OneVal dom, CMerge g1 g2 g)
        => LExp dom g1 One -> LExp dom g2 t -> LExp dom g t
letUnit e1 e2 = Dom proxyOne $ LetUnit merge e1 e2

vunit :: (HasOneSig sig, InDom sig OneExp OneVal dom)
      => LVal dom One
vunit = VDom proxyOne VUnit

instance (HasOneSig sig, InDom sig OneExp OneVal dom) 
      => Domain OneExp OneVal dom where
  substDomain _ pfA s (LetUnit pfM e1 e2) = 
    case mergeAddSplit pfM pfA of 
      Left  (pfA1,pfM1) -> Dom proxyOne $ LetUnit pfM1 (subst pfA1 s e1) e2
      Right (pfA2,pfM2) -> Dom proxyOne $ LetUnit pfM2 e1 (subst pfA2 s e2)

  evalDomain _ Unit = return vunit
  evalDomain proxy (LetUnit pfM e1 e2) = 
    case mergeEmpty pfM of {Dict -> do
      Just VUnit <- fmap (fromLVal proxy) $ eval' e1
      eval' e2
    }

  valToExpDomain _ VUnit = Unit

-- Tensor ------------------------------------------------------

data TensorSig ty = TensorSig ty ty

-- I claim: this type is valid as long as `HasTensorSig sig` holds
type (⊗) (s :: LType sig) (t :: LType sig) = 
     'Sig (InSig TensorSig sig) ('TensorSig s t)

class (Monad (SigEffect sig), CInSig TensorSig sig) => HasTensorSig sig
instance (Monad (SigEffect sig), CInSig TensorSig sig) => HasTensorSig sig

data TensorExp :: forall sig. ExpDom sig where
  Pair :: forall sig (exp :: Ctx sig -> LType sig -> *) g1 g2 g t1 t2.
          HasTensorSig sig => Merge g1 g2 g
       -> exp g1 t1 -> exp g2 t2 -> TensorExp exp g (t1 ⊗ t2)
  LetPair :: forall sig (exp :: Ctx sig -> LType sig -> *) 
                    g1 g2 g2' g2'' g x1 x2 s1 s2 t.
             HasTensorSig sig 
          => Merge g1 g2'' g -> AddCtx x1 s1 g2'' g2' -> AddCtx x2 s2 g2' g2
          -> exp g1 (s1 ⊗ s2) -> exp g2 t -> TensorExp exp g t
data TensorVal :: forall sig. ValDom sig where
  VPair :: forall sig (val :: LType sig -> *) t1 t2.
           HasTensorSig sig 
        => val t1 -> val t2 -> TensorVal val (t1 ⊗ t2)

proxyTensor :: (Proxy TensorExp, Proxy TensorVal)
proxyTensor = (Proxy,Proxy)

(⊗) :: (HasTensorSig sig, InDom sig TensorExp TensorVal dom, CMerge g1 g2 g)
     => LExp dom g1 s1 -> LExp dom g2 s2 -> LExp dom g (s1 ⊗ s2)
e1 ⊗ e2 = Dom proxyTensor $ Pair merge e1 e2

letPair :: forall sig (dom :: Dom sig) g g1 g2 g2' g2'' s1 s2 t.
         ( HasTensorSig sig, InDom sig TensorExp TensorVal dom
         , CAddCtx (Fresh g) s1 g2'' g2'
         , CAddCtx (Fresh2 g) s2 g2' g2
         , CMerge g1 g2'' g)
        => LExp dom g1 (s1 ⊗ s2)
        -> ((Var (Fresh g) s1, Var (Fresh2 g) s2) -> LExp dom g2 t)
        -> LExp dom g t
letPair e f = Dom proxyTensor $ LetPair pfM pfA1 pfA2 e e'
  where
    pfM :: Merge g1 g2'' g
    pfM = merge
    pfA1 :: AddCtx (Fresh g) s1 g2'' g2'
    pfA1 = addCtx
    pfA2 :: AddCtx (Fresh2 g) s2 g2' g2
    pfA2 = addCtx

    e' :: LExp dom g2 t
    e' = f (knownFresh g, knownFresh2 g)
    g :: SCtx g
    (_,_,g) = mergeSCtx pfM

vpair :: (HasTensorSig sig, InDom sig TensorExp TensorVal dom) 
      => LVal dom s1 -> LVal dom s2 -> LVal dom (s1 ⊗ s2)
vpair v1 v2 = VDom proxyTensor $ VPair v1 v2



instance (HasTensorSig sig, InDom sig TensorExp TensorVal dom)
      => Domain TensorExp TensorVal dom where
  substDomain proxy pfA s (Pair pfM e1 e2) = 
    case mergeAddSplit pfM pfA of
      Left  (pfA1,pfM1) -> Dom proxy $ Pair pfM1 (subst pfA1 s e1) e2
      Right (pfA2,pfM2) -> Dom proxy $ Pair pfM2 e1 (subst pfA2 s e2)
  substDomain proxy pfA s (LetPair pfM pfA1 pfA2 e e') = undefined -- TODO

  evalDomain _ (Pair pfM e1 e2) = 
    case mergeEmpty pfM of {Dict -> do
      v1 <- eval' e1
      v2 <- eval' e2
      return $ vpair v1 v2
    }
  evalDomain proxy (LetPair pfM pfA1 pfA2 e e') = 
    case mergeEmpty pfM of {Dict -> do
      Just (VPair v1 v2) <- fmap (fromLVal proxy) $ eval' e
      eval' $ subst pfA1 (valToExp v1) $ subst pfA2 (valToExp v2) e'
    }

  valToExpDomain _ (VPair v1 v2) = Pair MergeE (valToExp v1) (valToExp v2)

-- Lower -------------------------------------------------------

data LowerSig ty where
  LowerSig :: * -> LowerSig ty
class HasLowerSig sig where
  type Lower :: * -> LType sig

data LowerExp :: forall sig. ExpDom sig where
  Put :: a -> LowerExp exp 'Empty (Lower a)
  LetBang :: Merge g1 g2 g
          -> exp g1 (Lower a)
          -> (a -> exp g2 t)
          -> LowerExp exp g t
data LowerVal :: forall sig. ValDom sig where
  VPut :: a -> LowerVal val (Lower a)

proxyLower :: (Proxy LowerExp, Proxy LowerVal)
proxyLower = (Proxy,Proxy)

put :: (HasLowerSig sig, InDom sig LowerExp LowerVal dom)
    => a -> LExp dom 'Empty (Lower a)
put a = Dom proxyLower $ Put a

(>!) :: (HasLowerSig sig, InDom sig LowerExp LowerVal dom, CMerge g1 g2 g)
     => LExp dom g1 (Lower a)
     -> (a -> LExp dom g2 t)
     -> LExp dom g t
e >! f = Dom proxyLower $ LetBang merge e f

vput :: (HasLowerSig sig, InDom sig LowerExp LowerVal dom)
     => a -> LVal dom (Lower a)
vput a = VDom proxyLower $ VPut a

instance (HasLowerSig sig, InDom sig LowerExp LowerVal dom)
      => Domain LowerExp LowerVal dom where
  substDomain _ pfA s (LetBang pfM e f) =
    case mergeAddSplit pfM pfA of
      Left  (pfA1,pfM1) -> Dom proxyLower $ LetBang pfM1 (subst pfA1 s e) f
      Right (pfA2,pfM2) -> Dom proxyLower $ LetBang pfM2 e f'
        where
          f' x = subst pfA2 s (f x)

  evalDomain _ (Put a) = return $ vput a
  evalDomain _ (LetBang pfM e f) = 
    case mergeEmpty pfM of {Dict -> do
      Just (VPut a) <- fmap (fromLVal proxyLower) $ eval' e
      eval' $ f a
    }

  valToExpDomain _ (VPut a) = Put a


-- Additive Sums

data PlusSig ty = PlusSig ty ty
type (⊕) (s :: LType sig) (t :: LType sig) =
    'Sig (InSig PlusSig sig) ('PlusSig s t)

class (Monad (SigEffect sig), CInSig PlusSig sig) => HasPlusSig sig
instance (Monad (SigEffect sig), CInSig PlusSig sig) => HasPlusSig sig

data PlusExp :: forall sig. ExpDom sig where
  Inl  :: forall t2 t1 exp g. exp g t1 -> PlusExp exp g (t1 ⊕ t2)
  Inr  :: exp g t2 -> PlusExp exp g (t1 ⊕ t2)
  Case :: Merge g1 g2 g
       -> AddCtx x1 s1 g2 g21
       -> AddCtx x2 s2 g2 g22
       -> exp g1 (s1 ⊕ s2)
       -> exp g21 t
       -> exp g22 t
       -> PlusExp exp g t

data PlusVal :: forall sig. ValDom sig where
  VInl :: val t1 -> PlusVal val (t1 ⊕ t2)
  VInr :: val t2 -> PlusVal val (t1 ⊕ t2)

proxyPlus :: (Proxy PlusExp, Proxy PlusVal)
proxyPlus = (Proxy,Proxy)

inl :: (HasPlusSig sig, InDom sig PlusExp PlusVal dom)
    => LExp dom g t1 -> LExp dom g (t1 ⊕ t2)
inl e = Dom proxyPlus $ Inl e

inr :: (HasPlusSig sig, InDom sig PlusExp PlusVal dom)
    => LExp dom g t2 -> LExp dom g (t1 ⊕ t2)
inr e = Dom proxyPlus $ Inr e

caseof :: forall sig dom s1 s2 g g1 g2 g21 g22 t.
          (HasPlusSig sig, InDom sig PlusExp PlusVal dom,
           CAddCtx (Fresh g) s1 g2 g21,
           CAddCtx (Fresh g) s2 g2 g22,
           CMerge g1 g2 g)
       => LExp dom g1 (s1 ⊕ s2)
       -> (Var (Fresh g) s1 -> LExp dom g21 t)
       -> (Var (Fresh g) s2 -> LExp dom g22 t)
       -> LExp dom g t
caseof e f1 f2 = Dom proxyPlus $ Case merge pfA1 pfA2 e (f1 v1) (f2 v2)
  where
    pfA1 :: AddCtx (Fresh g) s1 g2 g21
    pfA1 = addCtx
    pfA2 :: AddCtx (Fresh g) s2 g2 g22
    pfA2 = addCtx
    v1 :: Var (Fresh g) s1
    v1 = addToSIdent pfA1
    v2 :: Var (Fresh g) s2
    v2 = addToSIdent pfA2

instance (HasPlusSig sig, InDom sig PlusExp PlusVal dom)
      => Domain PlusExp PlusVal dom where

  substDomain _ pfA s (Inl e) = inl $ subst pfA s e
  substDomain _ pfA s (Inr e) = inr $ subst pfA s e
  substDomain _ pfA s (Case pfM pfA1 pfA2 e e1 e2) =
    case mergeAddSplit pfM pfA of
      Left  (pfA1',pfM1) -> 
        Dom proxyPlus $ Case pfM1 pfA1 pfA2 (subst pfA1' s e) e1 e2
      Right (pfA2',pfM2) -> undefined -- TODO

  evalDomain _     (Inl e) = fmap (VDom proxyPlus . VInl) $ eval' e
  evalDomain _     (Inr e) = fmap (VDom proxyPlus . VInr) $ eval' e
  evalDomain proxy (Case pfM pfA1 pfA2 e e1 e2) = 
    case mergeEmpty pfM of {Dict -> do
      v <- eval' e
      case fromLVal proxy v of
        Just (VInl v1) -> eval' $ subst pfA1 (valToExp v1) e1
        Just (VInr v2) -> eval' $ subst pfA2 (valToExp v2) e2
    }   

  valToExpDomain _ (VInl v) = Inl $ valToExp v
  valToExpDomain _ (VInr v) = Inr $ valToExp v

-- Additive Product

data WithSig ty = WithSig ty ty
type (&) (s :: LType sig) (t :: LType sig) = 
    'Sig (InSig WithSig sig) ('WithSig s t)

class (Monad (SigEffect sig), CInSig WithSig sig) => HasWithSig sig
instance (Monad (SigEffect sig), CInSig WithSig sig) => HasWithSig sig

data WithExp :: forall sig. ExpDom sig where
  With  :: exp g t1 -> exp g t2 -> WithExp exp g (t1 & t2)
  Proj1 :: exp g (t1 & t2) -> WithExp exp g t1
  Proj2 :: exp g (t1 & t2) -> WithExp exp g t2
data WithVal :: forall sig. ValDom sig where
  VWith :: val t1 -> val t2 -> WithVal val (t1 & t2)

proxyWith :: (Proxy WithExp, Proxy WithVal)
proxyWith = (Proxy,Proxy)

(&) :: (HasWithSig sig, InDom sig WithExp WithVal dom)
    => LExp dom g t1 -> LExp dom g t2 -> LExp dom g (t1 & t2)
e1 & e2 = Dom proxyWith $ With e1 e2

proj1 :: (HasWithSig sig, InDom sig WithExp WithVal dom)
      => LExp dom g (t1 & t2) -> LExp dom g t1
proj1 = Dom proxyWith . Proj1

proj2 :: (HasWithSig sig, InDom sig WithExp WithVal dom)
      => LExp dom g (t1 & t2) -> LExp dom g t2
proj2 = Dom proxyWith . Proj2

instance (HasWithSig sig, InDom sig WithExp WithVal dom)
      => Domain WithExp WithVal dom where
  substDomain _ pfA s (With e1 e2) = subst pfA s e1 & subst pfA s e2
  substDomain _ pfA s (Proj1 e)    = proj1 $ subst pfA s e
  substDomain _ pfA s (Proj2 e)    = proj2 $ subst pfA s e


  -- TODO: Think about laziness and evaluation order
  evalDomain _ (With e1 e2) = do
    v1 <- eval' e1 
    v2 <- eval' e2
    return $ VDom proxyWith $ VWith v1 v2
  evalDomain _ (Proj1 e) = do
    Just (VWith v1 v2) <- fmap (fromLVal proxyWith) $ eval' e
    return v1
  evalDomain _ (Proj2 e) = do
    Just (VWith v1 v2) <- fmap (fromLVal proxyWith) $ eval' e
    return v2

  valToExpDomain _ (VWith v1 v2) = With (valToExp v1) (valToExp v2)


-- concrete examples

type MultiplicativeProductSig m = '(m,'[ OneSig, TensorSig ])
type MultiplicativeProductDom m = 
    ('[ '(OneExp,OneVal), '(TensorExp,TensorVal) ] 
      :: Dom (MultiplicativeProductSig m) )

swapMP :: Monad m => Lift (MultiplicativeProductDom m) (s ⊗ t ⊸ t ⊗ s)
swapMP = Suspend . λ $ \ pr ->
    var pr `letPair` \(x,y) ->
    var y ⊗ var x

-- instance HasOneSig '(m,MultiplicativeProductSig) where
--  type One = Sig' OneSig MultiplicativeProductSig 'OneSig
--instance Monad m => HasTensorSig '(m,MultiplicativeProductSig) where
--  type s ⊗ t = Sig' TensorSig MultiplicativeProductSig ('TensorSig s t)

--type MELL

{-


(&) :: LExp sig g t1
    -> LExp sig g t2
    -> LExp sig g (t1 & t2)
(&) = Prod





caseof :: forall sig g2 g g21 g22 g1 s1 s2 t.
          (CIn (Fresh g) s1 g21, CIn (Fresh g) s2 g22
          ,CAddCtx (Fresh g) s1 g2 g21
          ,CAddCtx (Fresh g) s2 g2 g22
          ,CMerge g1 g2 g
          ,KnownCtx g)
       => LExp sig g1 (s1 ⊕ s2)
       -> (Var (Fresh g) s1 -> LExp sig g21 t)
       -> (Var (Fresh g) s2 -> LExp sig g22 t)
       -> LExp sig g t
caseof e f1 f2 = Case merge pfA1 pfA2 e (f1 v1) (f2 v2)
  where
    pfA1 :: AddCtx (Fresh g) s1 g2 g21
    pfA1 = addCtx
    pfA2 :: AddCtx (Fresh g) s2 g2 g22
    pfA2 = addCtx
    v1 :: Var (Fresh g) s1
    v1 = knownFresh (ctx @g)
    v2 :: Var (Fresh g) s2
    v2 = knownFresh (ctx @g)




-- Linearity Monad and Comonad -------------------------------

type family Bang (dom :: Dom sig) (a :: LType sig) :: LType sig where
  Bang dom a = Lower (Lift dom a)
data Lin dom a where
  Lin :: Lift dom (Lower a) -> Lin dom a



instance Functor (Lin dom) where
  -- f :: a -> b
  -- a :: Lin a ~ Lift f (Lower a)
  -- fmap f a :: Lift (Lower b)
  fmap f (Lin (Suspend e)) = Lin . Suspend $ e >! \ x → put (f x)
instance Applicative (Lin dom) where
  pure a = Lin $ Suspend (put a)
  -- a :: Lift (Lower a) 
  -- f :: Lift (Lower (a -> b))
  -- f <*> a :: Lift (Lower b)
  Lin (Suspend f) <*> Lin (Suspend e) = Lin . Suspend $ e >! \ x -> 
                                                        f >! \ f' -> 
                                                        put (f' x)
instance Monad (Lin dom) where
  -- e :: Lin a = Lift (Lower a)
  -- f :: a -> Lift (Lower b)
  Lin (Suspend e) >>= f  = Lin . Suspend $ e >! \ x -> forceL (f x)



forceL :: Lin dom a -> LExp dom 'Empty (Lower a)
forceL (Lin e) = force e

suspendL :: LExp dom 'Empty (Lower a) -> Lin dom a
suspendL = Lin . Suspend 

evalL :: forall sig (dom :: Dom sig) a.
         Monad (SigEffect sig) => Lin dom a -> SigEffect sig (Lin dom a)
evalL (Lin e) = fmap Lin $ evalL' e where
  evalL' :: forall sig (dom :: Dom sig) a. Monad (SigEffect sig) 
         => Lift dom (Lower a) -> SigEffect sig (Lift dom (Lower a))
  evalL' (Suspend e) = fmap Suspend $ eval e

evalVal :: forall sig (dom :: Dom sig) a. Monad (SigEffect sig) 
        => Lin dom a -> SigEffect sig (LVal dom (Lower a))
evalVal (Lin (Suspend e)) = eval' e

run :: forall sig (dom :: Dom sig) a. Monad (SigEffect sig) 
    => Lin dom a -> SigEffect sig a
run e = do
  VPut a <- evalVal e
  return a

-- Monads in the linear fragment ----------------------------------

class LFunctor (f :: LType sig -> LType sig) where
  lfmap :: LExp dom 'Empty ((s ⊸ t) ⊸ f s ⊸ f t)
class LFunctor f => LApplicative (f :: LType sig -> LType sig) where
  lpure :: LExp dom 'Empty (s ⊸ f s)
  llift :: LExp dom 'Empty (f(s ⊸ t) ⊸ f s ⊸ f t)
class LApplicative m => LMonad (m :: LType sig -> LType sig) where
  lbind :: LExp dom 'Empty ( m s ⊸ (s ⊸ m t) ⊸ m t)

lowerT :: (a -> b) -> LExp dom 'Empty (Lower a ⊸ Lower b)
lowerT f = λ $ \x -> 
  var x >! \ a ->
  put $ f a

liftT :: LExp dom 'Empty (s ⊸ t) -> Lift dom s -> Lift dom t
liftT f e = Suspend $ f `app` force e

data LinT dom (f :: LType sig -> LType sig) a where
  LinT :: Lift dom (f (Lower a)) -> LinT dom f a

forceT :: LinT dom f a -> LExp dom 'Empty (f (Lower a))
forceT (LinT e) = force e

instance LFunctor f => Functor (LinT dom f) where
  fmap :: (a -> b) -> LinT dom f a -> LinT dom f b
  fmap f (LinT e) = LinT . Suspend $ lfmap `app` lowerT f `app` force e

instance LApplicative f => Applicative (LinT dom f) where
  pure :: a -> LinT dom f a
  pure a = LinT . Suspend $ lpure `app` put a

  (<*>) :: LinT dom f (a -> b) -> LinT dom f a -> LinT dom f b
  LinT f <*> LinT a = LinT . Suspend $ 
    llift `app` (lfmap `app` lowerT' `app` force f) `app` force a
    where
      lowerT' :: LExp dom 'Empty (Lower (a -> b) ⊸ Lower a ⊸ Lower b)
      lowerT' = λ $ \gl ->
                  var gl >! \g ->
                  lowerT g

instance LMonad m => Monad (LinT dom m) where
  (>>=) :: forall dom a b. 
           LinT dom m a -> (a -> LinT dom m b) -> LinT dom m b
  LinT ma >>= f = LinT . Suspend $ lbind `app` force ma `app` f'
    where
      f' :: LExp dom 'Empty (Lower a ⊸ m (Lower b))
      f' = λ $ \la ->
        var la >! \a ->
        forceT $ f a
    
    
-}
