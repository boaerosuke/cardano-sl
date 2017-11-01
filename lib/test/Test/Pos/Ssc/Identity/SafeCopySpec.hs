-- | This module tests SafeCopy instances.

module Test.Pos.Ssc.Identity.SafeCopySpec
       ( spec
       ) where

import           Test.Hspec         (Spec, describe)
import           Universum

import qualified Pos.Ssc.GodTossing as GT

import           Test.Pos.Helpers   (safeCopyTest)
import           Test.Pos.Util      (withDefConfiguration)

spec :: Spec
spec = withDefConfiguration $ describe "Ssc" $ do
    describe "SafeCopy instances" $ do
        safeCopyTest @GT.Commitment
        safeCopyTest @GT.CommitmentSignature
        safeCopyTest @GT.SignedCommitment
        safeCopyTest @GT.Opening
        safeCopyTest @GT.SscPayload
        safeCopyTest @GT.SscProof
