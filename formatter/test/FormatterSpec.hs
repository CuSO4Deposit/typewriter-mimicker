module Main (main) where

import Typewriter.Formatter

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual label expected actual =
  if expected == actual
    then pure ()
    else error (label <> "\nexpected: " <> show expected <> "\nactual:   " <> show actual)

main :: IO ()
main = do
  let blocks =
        parseBlocks
          "TITLE\n=====\n\nThis is a short paragraph that should wrap cleanly.\n\n    keep  spacing\n    and indentation\n\n- first item\n- second item\n"

  assertEqual
    "parseBlocks recognizes headings, paragraphs, pre blocks, and lists"
    [ Heading 1 "TITLE"
    , Paragraph "This is a short paragraph that should wrap cleanly."
    , Preformatted ["keep  spacing", "and indentation"]
    , BulletList ["first item", "second item"]
    ]
    blocks

  assertEqual
    "formatBlocks wraps paragraphs and preserves preformatted blocks"
    [ Line HeadingStyle "TITLE"
    , Line NormalStyle ""
    , Line NormalStyle "This is a short"
    , Line NormalStyle "paragraph that should"
    , Line NormalStyle "wrap cleanly."
    , Line NormalStyle ""
    , Line PreStyle "keep  spacing"
    , Line PreStyle "and indentation"
    , Line NormalStyle ""
    , Line NormalStyle "- first item"
    , Line NormalStyle "- second item"
    ]
    (formatBlocks (FormatOptions {formatColumns = 22}) blocks)

  let doc =
        emitDocument
          DocumentOptions
            { documentPaper = "letter"
            , documentColumns = 18
            , documentRows = 6
            , documentSeed = 7
            }
          (formatBlocks (FormatOptions 18) blocks)

  assertEqual "emitDocument records page spec" "letter" (pagePaper (documentPage doc))
  assertEqual "emitDocument records columns" 18 (pageColumns (documentPage doc))
  assertEqual "emitDocument paginates rows" 1 (maximumPage (documentGlyphs doc))

  case documentGlyphs doc of
    firstGlyph : _ -> do
      assertEqual "first glyph is first title character" 'T' (glyphChar firstGlyph)
      assertEqual "first glyph row" 0 (glyphRow firstGlyph)
      assertEqual "first glyph column" 0 (glyphCol firstGlyph)
      assertEqual "heading glyph style" HeadingStyle (glyphStyle firstGlyph)
    [] -> error "emitDocument produced no glyphs"

  let json = encodeDocumentJson doc
  assertEqual "json includes format version" True ("\"format_version\":1" `contains` json)
  assertEqual "json includes glyphs" True ("\"glyphs\"" `contains` json)

contains :: String -> String -> Bool
contains needle haystack = any (needle `prefixOf`) (suffixes haystack)

prefixOf :: Eq a => [a] -> [a] -> Bool
prefixOf [] _ = True
prefixOf _ [] = False
prefixOf (x : xs) (y : ys) = x == y && prefixOf xs ys

suffixes :: [a] -> [[a]]
suffixes [] = [[]]
suffixes xs@(_ : rest) = xs : suffixes rest

maximumPage :: [Glyph] -> Int
maximumPage [] = -1
maximumPage (glyph : rest) = foldr (max . glyphPage) (glyphPage glyph) rest
