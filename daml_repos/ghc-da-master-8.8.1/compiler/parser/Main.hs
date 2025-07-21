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
      let result = parse content
      print result
    _ -> putStrLn "Usage: runhaskell Main.hs <daml-file>"
