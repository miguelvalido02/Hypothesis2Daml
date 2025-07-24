-- Main.hs
module Main where

import Parser     -- from Parser.hs
import Lexer      -- from Lexer.hs
import System.IO
import System.Environment

main :: IO ()
main = do
  args <- getArgs
  case args of
    [file] -> do
      content <- readFile file
      let result = parseModule content -- Replace 'parse' with the actual top-level parse function in Parser.hs
      print result
    _ -> putStrLn "Usage: cabal run daml-parser-app <file.daml>"
  --_ -> putStrLn "Usage: runhaskell Main.hs <daml-file>"



      
   
