module Main (main) where

import System.Environment (getArgs)
import Typewriter.Formatter

main :: IO ()
main = do
  args <- getArgs
  case args of
    inputPath : rest -> do
      input <- readFile inputPath
      let options = parseOptions rest defaultDocumentOptions
          linesForDocument = formatBlocks (FormatOptions (documentColumns options)) (parseBlocks input)
      putStrLn (encodeDocumentJson (emitDocument options linesForDocument))
    [] -> fail "usage: typewriter-format INPUT [--cols N] [--rows N] [--paper NAME] [--seed N]"

parseOptions :: [String] -> DocumentOptions -> DocumentOptions
parseOptions [] options = options
parseOptions ("--cols" : value : rest) options =
  parseOptions rest options {documentColumns = read value}
parseOptions ("--rows" : value : rest) options =
  parseOptions rest options {documentRows = read value}
parseOptions ("--paper" : value : rest) options =
  parseOptions rest options {documentPaper = value}
parseOptions ("--seed" : value : rest) options =
  parseOptions rest options {documentSeed = read value}
parseOptions (unknown : _) _ = error ("unknown option: " <> unknown)
