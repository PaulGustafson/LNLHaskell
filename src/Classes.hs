{-# OPTIONS_GHC -fno-warn-redundant-constraints #-}

module Classes where

import Prelude hiding (div)
import Data.Singletons
import GHC.TypeLits hiding (Div)
import Data.Constraint
import Data.Type.Equality
import Unsafe.Coerce

--import Prelim
import Types

-- In Context ---------------------------------------------

class CIn (x :: Nat) (σ :: LType) (γ :: Ctx)

instance CIn x σ ('(x,σ) ': γ)
instance (CIn x σ γ) => CIn x σ ('(y,τ) ': γ)

-- Add To Context --------------------------------------------

--
class (γ' ~ AddF x σ γ, γ ~ Remove x γ', Lookup γ' x ~ Just σ, KnownNat x, WFCtx γ)
   => CAddCtx (x :: Nat) (σ :: LType) (γ :: Ctx) (γ' :: Ctx) 
    | x σ γ -> γ', x γ' -> σ γ

instance (γ' ~ AddF x σ γ, γ ~ Remove x γ', Lookup γ' x ~ Just σ, KnownNat x, WFCtx γ)
   => CAddCtx (x :: Nat) (σ :: LType) (γ :: Ctx) (γ' :: Ctx) 

addLookupNEq :: (γ' ~ AddF x σ γ, (x == y) ~ False)
             => Proxy x -> Proxy y -> Dict (Lookup γ' y ~ Lookup γ y)
addLookupNEq _ _ = unsafeCoerce (Dict :: Dict ())


-- Singleton Contexts ------------------------------------------

class (γ ~ SingletonF x σ, Remove x γ ~ '[], Lookup γ x ~ 'Just σ, KnownNat x
      ,γ ~ '[ '(x,σ) ])
   => CSingletonCtx (x :: Nat) (σ :: LType) (γ :: Ctx)
      | x σ -> γ, γ -> x σ 

instance (γ ~ SingletonF x σ
         , Remove x γ ~ '[]
         , Lookup γ x ~ 'Just σ
         , KnownNat x
         , γ ~ '[ '(x,σ) ])
   => CSingletonCtx (x :: Nat) (σ :: LType) (γ :: Ctx)

singletonLookupNEq :: forall x y σ. (x == y) ~ False 
                   => Proxy y -> Dict (Lookup '[ '(x,σ) ] y ~ Nothing)
singletonLookupNEq _ = unsafeCoerce (Dict :: Dict ())


-- Merging ---------------------------------------



class (γ ~ MergeF γ1 γ2, γ ~ MergeF γ2 γ1, Div γ γ2 ~ γ1, Div γ γ1 ~ γ2
      , WFCtx γ1, WFCtx γ2, WFCtx γ)
    => CMerge γ1 γ2 γ | γ1 γ2 -> γ, γ1 γ -> γ2, γ2 γ -> γ1

instance (γ ~ MergeF γ1 γ2, γ ~ MergeF γ2 γ1, Div γ γ2 ~ γ1, Div γ γ1 ~ γ2
      , WFCtx γ1, WFCtx γ2, WFCtx γ)
    => CMerge γ1 γ2 γ 

lookupMerge1 :: forall γ1 γ2 γ x σ.
                (γ ~ MergeF γ1 γ2, Lookup γ1 x ~ Just σ)
             => Proxy x 
             -> Dict (Lookup γ x ~ Just σ)
lookupMerge1 _ = unsafeCoerce (Dict :: Dict ())

lookupMerge2 :: forall γ1 γ2 γ x σ.
                (γ ~ MergeF γ1 γ2, Lookup γ2 x ~ Just σ)
             => Proxy x 
             -> Dict (Lookup γ x ~ Just σ)

lookupMerge2 _ = unsafeCoerce (Dict :: Dict ())


{-
split :: forall γ1 γ2 γ sig. CMerge γ1 γ2 γ 
       => ECtx sig γ -> (ECtx sig γ1, ECtx sig γ2)
split (ECtx f) = (ECtx $ \Dict x -> f (lookupMerge1 @γ1 @γ2 @γ x) x
                 ,ECtx $ \Dict x -> f (lookupMerge2 @γ1 @γ2 @γ x) x)
-}



-- Well-formed contexts --------------------------------

type WFCtx γ = (Div γ '[] ~ γ, Div  γ γ ~ '[]
               , MergeF '[] γ ~ γ, MergeF γ '[] ~ γ)


-- Helper stuff -----------------------------------

type WFVar x σ γ = ( CSingletonCtx x σ (SingletonF x σ)
                   , CAddCtx x σ γ (AddF x σ γ) 
                   , CMerge γ (SingletonF x σ) (AddF x σ γ)
                   , WFCtx γ
                   )
type WFFreshVar x σ γ = (WFVar x σ γ, x ~ Fresh γ)
class WFVar (Fresh γ) σ γ => WFFresh σ γ
instance WFVar (Fresh γ) σ γ => WFFresh σ γ


type WFVarTwo' x σ y τ γ γ' = ( x ~ Fresh γ, y ~ Fresh (AddF x σ γ)
                              , WFVar x σ γ, WFVar y τ (AddF x σ γ)
                              , WFVar y τ γ, WFVar x σ (AddF y τ γ)
                              , CAddCtx x σ (AddF y τ γ) γ'
                              , CAddCtx y τ (AddF x σ γ) γ'
                              , AddF x σ (AddF y τ γ) ~ AddF y τ (AddF x σ γ)
                              )
class WFVarTwo' x σ y τ γ γ' => WFVarTwo x σ y τ γ γ'
instance WFVarTwo' x σ y τ γ γ' => WFVarTwo x σ y τ γ γ'

type WFVarTwoFresh σ τ γ γ' = WFVarTwo (Fresh γ) σ (Fresh (AddF (Fresh γ) σ γ)) τ γ γ'

wfVarTwoFresh :: forall σ τ γ x y γ'. 
                 (x ~ Fresh γ, y ~ Fresh (AddF x σ γ), γ' ~ AddF y τ (AddF x σ γ))
              => Dict (WFVarTwo x σ y τ γ γ')
wfVarTwoFresh = unsafeCoerce (Dict :: Dict ())



type WFVarMerge x σ γ1 γ2 γ = ( WFVar x σ γ1, WFVar x σ γ2, WFVar x σ γ
                              , CMerge (AddF x σ γ1) γ2 (AddF x σ γ)
                              , CMerge γ1 (AddF x σ γ2) (AddF x σ γ)
                              )
class (WFVarMerge (Fresh γ) σ γ1 γ2 γ) => WFVarFreshMerge σ γ1 γ2 γ
instance (WFVarMerge (Fresh γ) σ γ1 γ2 γ) => WFVarFreshMerge σ γ1 γ2 γ

wfFreshMerge :: forall σ γ1 γ2 γ. CMerge γ1 γ2 γ
              => Dict (WFVarFreshMerge σ γ1 γ2 γ)
wfFreshMerge = unsafeCoerce (Dict :: Dict ())
