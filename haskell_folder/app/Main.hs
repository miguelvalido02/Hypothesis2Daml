{-# LANGUAGE DeriveGeneric #-}

module Main where

import GHC.Generics (Generic)
import Data.Aeson (FromJSON, eitherDecodeFileStrict')
import Test.QuickCheck
import qualified Data.Text as T
import System.Environment (getArgs)

-- Match JSON structure
data DamlModule = DamlModule
  { md_name      :: T.Text
  , md_functions :: [DamlFunction]
  , md_templates :: [Template]
  } deriving (Show, Generic)

instance FromJSON DamlModule

data DamlFunction = DamlFunction
  { fct_name :: T.Text
  } deriving (Show, Generic)

instance FromJSON DamlFunction

data Template = Template
  { tpl_name :: Maybe T.Text
  } deriving (Show, Generic)

instance FromJSON Template

-- === Properties ===
-- Prop 1
prop_hasAtLeastOneFunction :: DamlModule -> Bool
prop_hasAtLeastOneFunction mod = not (null (md_functions mod))

-- Prop 2
prop_allFunctionNamesAreLowercase :: DamlModule -> Bool
prop_allFunctionNamesAreLowercase =
  all (isLowercase . fct_name) . md_functions
  where
    isLowercase t = T.toLower t == t

-- === Entry Point ===

main :: IO ()
main = do
  args <- getArgs
  case args of
    [propName] -> runPropertyByName propName
    _ -> do
      putStrLn "Usage: testrunner <property-name>"
      putStrLn "Available properties:"
      mapM_ putStrLn
        [ "prop_hasAtLeastOneFunction"
        , "prop_allFunctionNamesAreLowercase"
        ]

runPropertyByName :: String -> IO ()
runPropertyByName prop = do
  result <- eitherDecodeFileStrict' "../daml_parser/output.json" :: IO (Either String [DamlModule]) -- output.json is the decoded daml file in JSON format
  case result of
    Left err -> putStrLn $ "Failed to parse JSON: " ++ err
    Right mods -> do
      putStrLn $ "Parsed " ++ show (length mods) ++ " module(s)."
      mapM_ (runProp prop) mods

runProp :: String -> DamlModule -> IO ()
runProp prop mod =
  case prop of
    "prop_hasAtLeastOneFunction"       -> quickCheck (prop_hasAtLeastOneFunction mod)
    "prop_allFunctionNamesAreLowercase" -> quickCheck (prop_allFunctionNamesAreLowercase mod)
    _ -> putStrLn $ "Unknown property: " ++ prop
