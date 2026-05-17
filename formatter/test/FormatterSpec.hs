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
          "TITLE\n=====\n\nUsage\n-----\n\nThis is a short paragraph that should wrap cleanly.\n\n    keep  spacing\n    and indentation\n\n- first item\n- second item\n"

  assertEqual
    "parseBlocks recognizes headings, paragraphs, pre blocks, and lists"
    [ Heading 1 "TITLE"
    , Preformatted ["====="]
    , BlankLine
    , Heading 2 "Usage"
    , Preformatted ["-----"]
    , BlankLine
    , Paragraph ["This is a short paragraph that should wrap cleanly."]
    , BlankLine
    , Preformatted ["    keep  spacing", "    and indentation"]
    , BlankLine
    , BulletList ["first item", "second item"]
    ]
    blocks

  assertEqual
    "formatBlocks wraps paragraphs and preserves preformatted blocks"
    [ Line HeadingStyle "TITLE"
    , Line PreStyle "====="
    , Line NormalStyle ""
    , Line HeadingStyle "Usage"
    , Line PreStyle "-----"
    , Line NormalStyle ""
    , Line NormalStyle "This is a short paragr"
    , Line NormalStyle "aph that should wrap c"
    , Line NormalStyle "leanly."
    , Line NormalStyle ""
    , Line PreStyle "    keep  spacing"
    , Line PreStyle "    and indentation"
    , Line NormalStyle ""
    , Line NormalStyle "- first item"
    , Line NormalStyle "- second item"
    ]
    (formatBlocks (FormatOptions {formatColumns = 22}) blocks)

  assertEqual
    "parseBlocks preserves lightly indented option lines"
    [Preformatted ["  --cols N", "  Number of columns."]]
    (parseBlocks "  --cols N\n  Number of columns.\n")

  assertEqual
    "formatBlocks preserves plain input newlines and blank lines"
    [ Line NormalStyle "first"
    , Line NormalStyle "second"
    , Line NormalStyle ""
    , Line NormalStyle ""
    , Line NormalStyle "third"
    ]
    (formatBlocks (FormatOptions {formatColumns = 22}) (parseBlocks "first\nsecond\n\n\nthird\n"))

  assertEqual
    "formatBlocks preserves user-controlled spacing in plain lines"
    [ Line NormalStyle "Name:      Bee's Knees  "
    , Line NormalStyle "52.5 mL     Dry Gin"
    ]
    (formatBlocks (FormatOptions {formatColumns = 40}) (parseBlocks "Name:      Bee's Knees  \n52.5 mL     Dry Gin\n"))

  assertEqual
    "formatBlocks preserves user-controlled spacing in bullet items"
    [ Line NormalStyle "- 10 mL       Honey Syrup"
    ]
    (formatBlocks (FormatOptions {formatColumns = 40}) (parseBlocks "- 10 mL       Honey Syrup\n"))

  let pagedDoc =
        emitDocument
          DocumentOptions
            { documentPaper = "letter"
            , documentColumns = 18
            , documentRows = 6
            , documentSeed = 7
            }
          (formatBlocks (FormatOptions 18) (parseBlocks "before\n\f\nafter\n"))

  assertEqual
    "form feed advances the next typed line to a new page"
    [(0, 0, 'b'), (1, 0, 'a')]
    (map glyphPositionSummary (leadingGlyphsByLine (documentGlyphs pagedDoc)))

  let escapedPagedDoc =
        emitDocument
          DocumentOptions
            { documentPaper = "letter"
            , documentColumns = 18
            , documentRows = 6
            , documentSeed = 7
            }
          (formatBlocks (FormatOptions 18) (parseBlocks "before\n\\f\nafter\n"))

  assertEqual
    "escaped form feed line also advances the next typed line to a new page"
    [(0, 0, 'b'), (1, 0, 'a')]
    (map glyphPositionSummary (leadingGlyphsByLine (documentGlyphs escapedPagedDoc)))

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
  assertEqual "emitDocument paginates rows" 2 (maximumPage (documentGlyphs doc))

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

leadingGlyphsByLine :: [Glyph] -> [Glyph]
leadingGlyphsByLine [] = []
leadingGlyphsByLine (glyph : rest) = glyph : leadingGlyphsByLine (dropWhile (sameLine glyph) rest)

sameLine :: Glyph -> Glyph -> Bool
sameLine left right = glyphPage left == glyphPage right && glyphRow left == glyphRow right

glyphPositionSummary :: Glyph -> (Int, Int, Char)
glyphPositionSummary glyph = (glyphPage glyph, glyphRow glyph, glyphChar glyph)
