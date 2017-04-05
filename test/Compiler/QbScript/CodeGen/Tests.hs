module Compiler.QbScript.CodeGen.Tests where

import Compiler.QbScript.AST
import Compiler.QbScript.CodeGen
import Data.GH3.QB

import Control.Monad.Reader(runReaderT)
import qualified Data.ByteString as B
import Data.Packer(Packing, runPacking)
import Data.Word(Word8)
import Test.Hspec

testPacking :: Packing () -> [Word8]
testPacking = B.unpack . runPacking 4096

runTests :: Spec
runTests = do
  instrTests
  smallLitTests
  litTests
  dictTests
  arrayTests
  exprTests
  structTests
  structArrayTests

instrTests :: Spec
instrTests =
  describe "putInstr" $ do
    it "generates an assignment correctly" $
      testPacking (putInstr (Assign (NonLocal . QbName $ "x") (ELit . SmallLit . LitN $ 2)))
         `shouldBe` [0x01, 0x16, 0x7C, 0xE9, 0x23, 0x73, 0x07, 0x17, 0x02, 0x00, 0x00, 0x00]
    it "generates an if with no else branches correctly" $
      testPacking (putInstr (IfElse (ELit LitPassthrough, [BareExpr $ ELit LitPassthrough])
                                    [] []))
        `shouldBe` [ 0x01, 0x47, 0x07, 0x00, 0x2C, 0x01, 0x2C, 0x01, 0x28 ]
    it "generates an if/else correctly" $
      testPacking (putInstr (IfElse (ELit LitPassthrough, [BareExpr $ ELit LitPassthrough])
                                    []
                                    [BareExpr $ ELit LitPassthrough]))
        `shouldBe` [ 0x01, 0x47, 0x09, 0x00, 0x2C, 0x01, 0x2C
                   , 0x01, 0x48, 0x06, 0x00, 0x01, 0x2C, 0x01, 0x28]
    it "generates an if/elseif/else correctly" $
      testPacking (putInstr (IfElse (ELit LitPassthrough, [BareExpr $ ELit LitPassthrough])
                                   [(ELit LitPassthrough, [BareExpr $ ELit LitPassthrough])]
                                    [BareExpr $ ELit LitPassthrough]))
        `shouldBe` [ 0x01, 0x47, 0x06, 0x00, 0x2C, 0x01, 0x2C
                   , 0x01, 0x27, 0x0B, 0x00, 0x0D, 0x00, 0x2C, 0x01, 0x2C
                   , 0x01, 0x48, 0x06, 0x00, 0x01, 0x2C, 0x01, 0x28 ]
    it "generates a repeat correctly" $
      testPacking (putInstr (Repeat (Just . ELit . SmallLit . LitN $ 4) [BareExpr $ ELit LitPassthrough]))
        `shouldBe` [ 0x01, 0x20, 0x01, 0x2C, 0x01, 0x21, 0x17, 0x04, 0x00, 0x00, 0x00 ]
    it "generates an infinite repeat correctly" $
      testPacking (putInstr (Repeat Nothing [BareExpr $ ELit LitPassthrough]))
        `shouldBe` [ 0x01, 0x20, 0x01, 0x2C, 0x01, 0x21 ]
    it "generates a switch/case/default correctly" $
      testPacking (putInstr (Switch (ELit . SmallLit . LitN $ 2)
                                   [(LitN 1, [BareExpr $ ELit LitPassthrough])
                                   ,(LitN 2, [BareExpr $ ELit LitPassthrough])]
                                    [BareExpr $ ELit LitPassthrough]))
        `shouldBe` [ 0x01, 0x3C, 0x17, 0x02, 0x00, 0x00, 0x00
                   , 0x01, 0x3E, 0x49, 0x0D, 0x00, 0x17, 0x01, 0x00, 0x00, 0x00, 0x01, 0x2C
                   , 0x01, 0x49, 0x19, 0x00, 0x3E, 0x49, 0x0D, 0x00, 0x17, 0x02, 0x00, 0x00, 0x00, 0x01, 0x2C
                   , 0x01, 0x49, 0x0A, 0x00, 0x3F, 0x49, 0x05, 0x00, 0x01, 0x2C
                   , 0x01, 0x3D ]
    it "generates a break correctly" $
      testPacking (putInstr Break) `shouldBe` [ 0x01, 0x22 ]
    it "generates return correctly" $ do
      testPacking (putInstr $ Return Nothing) `shouldBe` [ 0x01, 0x29 ]
      testPacking (putInstr $ Return (Just (Nothing, ELit . SmallLit . LitN $ 2)))
        `shouldBe` [ 0x01, 0x29, 0x17, 0x02, 0x00, 0x00, 0x00 ]
      testPacking (putInstr $ Return (Just (Just (QbName "x"), ELit . SmallLit . LitN $ 2)))
        `shouldBe` [ 0x01, 0x29, 0x16, 0x7C, 0xE9, 0x23, 0x73, 0x07, 0x17, 0x02, 0x00, 0x00, 0x00 ]

smallLitTests :: Spec
smallLitTests =
  describe "putSmallLit" $ do
    it "generates an integer correctly" $
      testPacking (putSmallLit (LitN 3)) `shouldBe` [ 0x17, 0x03, 0x00, 0x00, 0x00 ]
    it "generates a hex integer correctly" $
      testPacking (putSmallLit (LitH 0x24)) `shouldBe` [ 0x18, 0x24, 0x00, 0x00, 0x00 ]
    it "generates a key by checksum correctly" $
      testPacking (putSmallLit (LitKey . NonLocal . QbCrc $ 0x78563412)) `shouldBe` [ 0x16, 0x12, 0x34, 0x56, 0x78 ]
    it "generates a key by name correctly" $
      testPacking (putSmallLit (LitKey . NonLocal . QbName $ "x")) `shouldBe` [ 0x16, 0x7C, 0xE9, 0x23, 0x73 ]
    it "generates a local key by checksum correctly" $
      testPacking (putSmallLit (LitKey . Local . QbCrc $ 0x78563412)) `shouldBe` [ 0x2D, 0x16, 0x12, 0x34, 0x56, 0x78 ]
    it "generates a local key by name correctly" $
      testPacking (putSmallLit (LitKey . Local . QbName $ "x")) `shouldBe` [ 0x2D, 0x16, 0x7C, 0xE9, 0x23, 0x73 ]

litTests :: Spec
litTests =
  describe "putLit" $ do
    it "generates a float correctly" $
      testPacking (putLit (LitF 1)) `shouldBe` [ 0x1A, 0x00, 0x00, 0x80, 0x3F ]
    it "generates a vector2 correctly" $
      testPacking (putLit (LitV2 1 1)) `shouldBe` [ 0x1F, 0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x80, 0x3F ]
    it "generates a vector3 correctly" $
      testPacking (putLit (LitV3 1 1 1)) `shouldBe` [ 0x1E, 0x00, 0x00, 0x80, 0x3F
                                                          , 0x00, 0x00, 0x80, 0x3F
                                                          , 0x00, 0x00, 0x80, 0x3F ]
    it "generates a narrow string correctly" $
      testPacking (putLit (LitString "HelloWorld")) `shouldBe` [ 0x1B, 0x0B, 0x00, 0x00, 0x00
                                                               , 0x48, 0x65, 0x6C, 0x6C, 0x6F
                                                               , 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x00 ]
    it "generates a wide string correctly" $
      testPacking (putLit (LitWString "HelloWorld")) `shouldBe`
        [ 0x4C, 0x16, 0x00, 0x00, 0x00
        , 0x00, 0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F
        , 0x00, 0x57, 0x00, 0x6F, 0x00, 0x72, 0x00, 0x6C, 0x00, 0x64, 0x00, 0x00 ]
    it "generates a struct correctly" $
      testPacking (putLit (LitStruct (Struct []))) `shouldBe`
        [ 0x4A, 0x08, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00 ]

dictTests :: Spec
dictTests =
  describe "putLitDict" $ do
    it "generates an empty dict correctly" $
      testPacking (putLitDict (Dict [])) `shouldBe` [ 0x03, 0x01, 0x04 ]
    it "generates a dict with a single kv-item correctly"  $
      testPacking (putLitDict (Dict [(Just $ QbName "x", ELit LitPassthrough)]))
        `shouldBe` [ 0x03, 0x01, 0x16, 0x7C, 0xE9, 0x23, 0x73, 0x07, 0x2C, 0x01, 0x04 ]

arrayTests :: Spec
arrayTests =
  describe "putLitArray" $ do
    it "generates an empty array correctly" $
      testPacking (putLitArray (Array []))
        `shouldBe` [ 0x05, 0x06 ]
    it "generates a 1-element array correctly" $
      testPacking (putLitArray (Array [BareCall (QbName "f") []]))
        `shouldBe` [ 0x05, 0x16, 0x1F, 0xD4, 0x2C, 0x89, 0x06 ]
    it "generates a 2-element array correctly" $
      testPacking (putLitArray (Array [BareCall (QbName "f") [], BareCall (QbName "x") []]))
        `shouldBe` [ 0x05, 0x16, 0x1F, 0xD4, 0x2C, 0x89, 0x09, 0x16, 0x7C, 0xE9, 0x23, 0x73, 0x06 ]

exprTests :: Spec
exprTests =
    describe "putExpr" $ do
      it "generates simple expressions with minimal nesting correctly" $ do
        testPacking (putExpr (Paren one)) `shouldBe` concat [[0x0E], putOne, [0x0F]]
        testPacking (putExpr (Neg one)) `shouldBe` 0x0A:putOne
        testPacking (putExpr (Not one)) `shouldBe` 0x39:putOne
        testPacking (putExpr (And one one)) `shouldBe` concat [putOne, [0x33], putOne]
        testPacking (putExpr (Or one one)) `shouldBe` concat [putOne, [0x32], putOne]
        testPacking (putExpr (Xor one one)) `shouldBe` concat [putOne, [0x34], putOne]
        testPacking (putExpr (Add one one)) `shouldBe` concat [putOne, [0x0B], putOne]
        testPacking (putExpr (Sub one one)) `shouldBe` concat [putOne, [0x0A], putOne]
        testPacking (putExpr (Mul one one)) `shouldBe` concat [putOne, [0x0D], putOne]
        testPacking (putExpr (Div one one)) `shouldBe` concat [putOne, [0x0C], putOne]
        testPacking (putExpr (Lt one one)) `shouldBe` concat [putOne, [0x12], putOne]
        testPacking (putExpr (Lte one one)) `shouldBe` concat [putOne, [0x13], putOne]
        testPacking (putExpr (Eq one one)) `shouldBe` concat [putOne, [0x07], putOne]
        testPacking (putExpr (Gt one one)) `shouldBe` concat [putOne, [0x14], putOne]
        testPacking (putExpr (Gte one one)) `shouldBe` concat [putOne, [0x15], putOne]
        testPacking (putExpr (Neq one one)) `shouldBe` concat [putOne, [0x4D], putOne]
        testPacking (putExpr (Deref one)) `shouldBe` 0x4B:putOne
        testPacking (putExpr (Index one one)) `shouldBe` concat [putOne, [0x05], putOne, [0x06]]
        testPacking (putExpr (Member one x)) `shouldBe` concat [putOne, [0x08], putX]
        testPacking (putExpr (BareCall x [(Nothing, one)])) `shouldBe` putX ++ putOne
        testPacking (putExpr (MethodCall (NonLocal x) x [(Nothing, one)])) `shouldBe`
          concat [putX, [0x42], putX, putOne]
      -- TODO: test more complicated expressions
      return ()
  where
    one = ELit (LitF 1)
    putOne = [ 0x1A, 0x00, 0x00, 0x80, 0x3F ]
    x = QbName "x"
    putX = [ 0x16, 0x7C, 0xE9, 0x23, 0x73 ]

testPackStruct :: Struct -> [Word8]
testPackStruct s = testPacking (runReaderT (putStruct s) 0)

structStartHeader :: [Word8]
structStartHeader = [ 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x08 ]

structTests :: Spec
structTests =
  describe "putStruct" $ do
    it "generates a 1-element struct correctly" $ do
      testPackStruct (Struct [StructItem QbTInteger (QbCrc 0x12345678) (QbInteger 5)])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x81, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00 ]
      testPackStruct (Struct [StructItem QbTFloat (QbCrc 0x12345678) (QbFloat 1)])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x82, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x3f, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ]
      testPackStruct (Struct [StructItem QbTString (QbCrc 0x12345678) (QbString "abcd")])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x83, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00
                   , 0x61, 0x62, 0x63, 0x64, 0x00 ]
      testPackStruct (Struct [StructItem QbTWString (QbCrc 0x12345678) (QbWString "abcd")])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x84, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00
                   , 0x00, 0x61, 0x00, 0x62, 0x00, 0x63, 0x00, 0x64, 0x00, 0x00 ]
      testPackStruct (Struct [StructItem QbTVector2 (QbCrc 0x12345678) (QbVector2 1 1)])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x85, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00
                   , 0x00, 0x01, 0x00, 0x00, 0x3f, 0x80, 0x00, 0x00, 0x3f, 0x80, 0x00, 0x00 ]
      testPackStruct (Struct [StructItem QbTVector3 (QbCrc 0x12345678) (QbVector3 1 1 1)])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x86, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00
                   , 0x00, 0x01, 0x00, 0x00, 0x3f, 0x80, 0x00, 0x00, 0x3f, 0x80, 0x00, 0x00, 0x3f, 0x80, 0x00, 0x00 ]
      testPackStruct (Struct [StructItem QbTStruct (QbCrc 0x12345678) (QbStruct $
                      Struct [StructItem QbTInteger (QbCrc 0x00000000) (QbInteger 3)])])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x8A, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00
                   , 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x20
                   , 0x00, 0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00]
      testPackStruct (Struct [StructItem (QbTArray QbTInteger) (QbCrc 0x12345678) (QbArray
                                        (QbArr QbTInteger [QbInteger 3, QbInteger 4]))])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x8C, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00
                   , 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x24
                   , 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04 ]
      testPackStruct (Struct [StructItem QbTKey (QbCrc 0x12345678) (QbKey $ QbName "x")])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x8D, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x73, 0x23, 0xE9, 0x7C, 0x00, 0x00, 0x00, 0x00 ]
      testPackStruct (Struct [StructItem QbTKeyRef (QbCrc 0x12345678) (QbKey $ QbName "x")])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x9A, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x73, 0x23, 0xE9, 0x7C, 0x00, 0x00, 0x00, 0x00 ]
      testPackStruct (Struct [StructItem QbTStringPointer (QbCrc 0x12345678) (QbKey $ QbName "x")])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x9B, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x73, 0x23, 0xE9, 0x7C, 0x00, 0x00, 0x00, 0x00 ]
      testPackStruct (Struct [StructItem QbTStringQs (QbCrc 0x12345678) (QbKey $ QbName "x")])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x9C, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x73, 0x23, 0xE9, 0x7C, 0x00, 0x00, 0x00, 0x00 ]
    it "generates a 2-element struct with appropriate padding between items" $ do
      testPackStruct (Struct [StructItem QbTInteger (QbCrc 0xabcdef90) (QbInteger 5)
                             ,StructItem QbTString (QbCrc 0x12345678) (QbString "abcd")])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x81, 0x00, 0x00, 0xAB, 0xCD, 0xEF, 0x90, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x18
                   , 0x00, 0x83, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x00, 0x00, 0x00, 0x28, 0x00, 0x00, 0x00, 0x00
                   , 0x61, 0x62, 0x63, 0x64, 0x00 ]
      testPackStruct (Struct [StructItem QbTString (QbCrc 0x12345678) (QbString "abcd")
                             ,StructItem QbTInteger (QbCrc 0xabcdef90) (QbInteger 5)])
        `shouldBe` structStartHeader ++
                   [ 0x00, 0x83, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x20
                   , 0x61, 0x62, 0x63, 0x64, 0x00, 0x00, 0x00, 0x00
                   , 0x00, 0x81, 0x00, 0x00, 0xAB, 0xCD, 0xEF, 0x90, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00 ]

testPackArray :: QbArray -> [Word8]
testPackArray a = testPacking (runReaderT (putQbArray a) 0)

structArrayTests :: Spec
structArrayTests =
  describe "putQbArray" $ do
    it "generates an empty array correctly" $
      testPackArray (QbArr QbTInteger []) `shouldBe` [ 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00 ]
    it "generates a singleton array of a value type correctly" $
      testPackArray (QbArr QbTFloat [QbFloat 1]) `shouldBe`
        [ 0x00, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0x01, 0x3f, 0x80, 0x00, 0x00 ]
    it "generates a singleton array of a reference type correctly" $ do
      testPackArray (QbArr QbTString [QbString "abcd"]) `shouldBe`
        [ 0x00, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x0C
        , 0x61, 0x62, 0x63, 0x64, 0x00 ]
      testPackArray (QbArr (QbTArray QbTInteger) [QbArray $ QbArr QbTInteger [QbInteger 1]]) `shouldBe`
        [ 0x00, 0x01, 0x0C, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x0C
        , 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01 ]
      testPackArray (QbArr QbTStruct [QbStruct $ Struct [StructItem QbTInteger (QbCrc 0) (QbInteger 1)]]) `shouldBe`
        [ 0x00, 0x01, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x0C
        , 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x14
        , 0x00, 0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]
    it "generates an array of value types correctly" $ do
      testPackArray (QbArr QbTFloat [QbFloat 1, QbFloat 2, QbFloat 3]) `shouldBe`
        [ 0x00, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x0C
        , 0x3F, 0x80, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x40, 0x40, 0x00, 0x00 ]
      testPackArray (QbArr QbTInteger [QbInteger 1, QbInteger 2, QbInteger 3, QbInteger 4]) `shouldBe`
        [ 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x0C
        , 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04 ]
    it "generates an array of reference types correctly" $ do
      testPackArray (QbArr QbTVector2 [QbVector2 1 1, QbVector2 2 2]) `shouldBe`
        [ 0x00, 0x01, 0x05, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x0C
        , 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x20
        , 0x00, 0x01, 0x00, 0x00, 0x3f, 0x80, 0x00, 0x00, 0x3f, 0x80, 0x00, 0x00
        , 0x00, 0x01, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00]
      testPackArray (QbArr QbTString [QbString "abcd", QbString "efgh", QbString "ijkl"]) `shouldBe`
        [ 0x00, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x0C
        , 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x1D, 0x00, 0x00, 0x00, 0x22
        , 0x61, 0x62, 0x63, 0x64, 0x00, 0x65, 0x66, 0x67, 0x68, 0x00, 0x69, 0x6A, 0x6B, 0x6C, 0x00 ]
      testPackArray (QbArr (QbTArray (QbTArray QbTInteger))
                      [QbArray $ QbArr QbTInteger [QbInteger 1]
                      ,QbArray $ QbArr QbTInteger [QbInteger 2]]) `shouldBe`
        [ 0x00, 0x01, 0x0C, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x0C
        , 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x20
        , 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01
        , 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02 ]
      testPackArray (QbArr QbTStruct [QbStruct $ Struct [StructItem QbTInteger (QbCrc 0) (QbInteger 1)]
                                     ,QbStruct $ Struct [StructItem QbTInteger (QbCrc 0) (QbInteger 2)]]) `shouldBe`
        [ 0x00, 0x01, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x0C
        , 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x2C
        , 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x1C
        , 0x00, 0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00
        , 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x34
        , 0x00, 0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00
        ]
