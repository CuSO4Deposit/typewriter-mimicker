module Typewriter.Formatter
  ( Block (..)
  , Document (..)
  , DocumentOptions (..)
  , FormatOptions (..)
  , Glyph (..)
  , Line (..)
  , PageSpec (..)
  , Style (..)
  , defaultDocumentOptions
  , emitDocument
  , encodeDocumentJson
  , formatBlocks
  , parseBlocks
  )
where

import Data.Char (isSpace)

data Block
  = Heading Int String
  | Paragraph String
  | Preformatted [String]
  | BulletList [String]
  | Rule
  | PageBreak
  deriving (Eq, Show)

data Style
  = NormalStyle
  | HeadingStyle
  | PreStyle
  deriving (Eq, Show)

data Line = Line
  { lineStyle :: Style
  , lineText :: String
  }
  deriving (Eq, Show)

newtype FormatOptions = FormatOptions
  { formatColumns :: Int
  }
  deriving (Eq, Show)

data DocumentOptions = DocumentOptions
  { documentPaper :: String
  , documentColumns :: Int
  , documentRows :: Int
  , documentSeed :: Int
  }
  deriving (Eq, Show)

data PageSpec = PageSpec
  { pagePaper :: String
  , pageColumns :: Int
  , pageRows :: Int
  }
  deriving (Eq, Show)

data Glyph = Glyph
  { glyphChar :: Char
  , glyphPage :: Int
  , glyphRow :: Int
  , glyphCol :: Int
  , glyphStyle :: Style
  , glyphSeed :: Int
  }
  deriving (Eq, Show)

data Document = Document
  { documentFormatVersion :: Int
  , documentPage :: PageSpec
  , documentGlyphs :: [Glyph]
  }
  deriving (Eq, Show)

defaultDocumentOptions :: DocumentOptions
defaultDocumentOptions =
  DocumentOptions
    { documentPaper = "letter"
    , documentColumns = 72
    , documentRows = 58
    , documentSeed = 1
    }

parseBlocks :: String -> [Block]
parseBlocks input = parseLines (lines input)

parseLines :: [String] -> [Block]
parseLines [] = []
parseLines (" " : rest) = parseLines rest
parseLines (line : rest)
  | blank line = parseLines rest
  | isHeadingUnderline rest =
      Heading (headingLevel (headLine rest)) (trimRight line) : Preformatted [headLine rest] : parseLines (drop 1 rest)
  | isIndented line =
      let (preLines, remaining) = span isIndented (line : rest)
       in Preformatted preLines : parseLines remaining
  | isBullet line =
      let (items, remaining) = span isBullet (line : rest)
       in BulletList (map bulletText items) : parseLines remaining
  | line == "---" = Rule : parseLines rest
  | line == "\f" = PageBreak : parseLines rest
  | otherwise =
      let (paraLines, remaining) = span paragraphLine (line : rest)
       in Paragraph (unwords (map trim paraLines)) : parseLines remaining

isHeadingUnderline :: [String] -> Bool
isHeadingUnderline (line : _) = isUnderline line
isHeadingUnderline [] = False

isUnderline :: String -> Bool
isUnderline line = not (null line) && (all (== '=') line || all (== '-') line)

headingLevel :: String -> Int
headingLevel line
  | all (== '=') line = 1
  | all (== '-') line = 2
  | otherwise = 3

headLine :: [String] -> String
headLine (line : _) = line
headLine [] = ""

paragraphLine :: String -> Bool
paragraphLine line =
  not (blank line)
    && not (isIndented line)
    && not (isBullet line)
    && not (isUnderline line)
    && line /= "---"
    && line /= "\f"

isBullet :: String -> Bool
isBullet ('-' : ' ' : _) = True
isBullet ('*' : ' ' : _) = True
isBullet _ = False

bulletText :: String -> String
bulletText (_ : ' ' : rest) = rest
bulletText line = line

isIndented :: String -> Bool
isIndented line = not (blank line) && take 1 line == " "

blank :: String -> Bool
blank = all isSpace

trim :: String -> String
trim = trimLeft . trimRight

trimLeft :: String -> String
trimLeft = dropWhile isSpace

trimRight :: String -> String
trimRight = reverse . dropWhile isSpace . reverse

formatBlocks :: FormatOptions -> [Block] -> [Line]
formatBlocks options = joinWithBlank . map (formatBlock options)

formatBlock :: FormatOptions -> Block -> [Line]
formatBlock _ (Heading _ text) = [Line HeadingStyle text]
formatBlock options (Paragraph text) = map (Line NormalStyle) (wrapText (formatColumns options) text)
formatBlock _ (Preformatted ls) = map (Line PreStyle) ls
formatBlock options (BulletList items) = map (Line NormalStyle) (concatMap (wrapBullet (formatColumns options)) items)
formatBlock options Rule = [Line NormalStyle (replicate (formatColumns options) '-')]
formatBlock _ PageBreak = [Line NormalStyle "\f"]

joinWithBlank :: [[Line]] -> [Line]
joinWithBlank [] = []
joinWithBlank [x] = x
joinWithBlank (x : y : rest)
  | isHeadingUnderlinePair x y = x ++ joinWithBlank (y : rest)
joinWithBlank (x : xs) = x ++ [Line NormalStyle ""] ++ joinWithBlank xs

isHeadingUnderlinePair :: [Line] -> [Line] -> Bool
isHeadingUnderlinePair [Line HeadingStyle _] [Line PreStyle underline] =
  isUnderline underline
isHeadingUnderlinePair _ _ = False

wrapBullet :: Int -> String -> [String]
wrapBullet width item =
  case wrapText (max 1 (width - 2)) item of
    [] -> ["- "]
    first : rest -> ("- " <> first) : map ("  " <>) rest

wrapText :: Int -> String -> [String]
wrapText width text = go [] (words text)
 where
  go acc [] = reverse acc
  go [] (word : rest) = go [word] rest
  go (line : done) (word : rest)
    | length line + 1 + length word <= width = go ((line <> " " <> word) : done) rest
    | otherwise = go (word : line : done) rest

emitDocument :: DocumentOptions -> [Line] -> Document
emitDocument options formattedLines =
  Document
    { documentFormatVersion = 1
    , documentPage =
        PageSpec
          { pagePaper = documentPaper options
          , pageColumns = documentColumns options
          , pageRows = documentRows options
          }
    , documentGlyphs = concatMap (lineGlyphs options) (zip [0 ..] formattedLines)
    }

lineGlyphs :: DocumentOptions -> (Int, Line) -> [Glyph]
lineGlyphs options (lineIndex, Line style text) =
  let rows = documentRows options
      page = lineIndex `div` rows
      row = lineIndex `mod` rows
   in [ Glyph
          { glyphChar = ch
          , glyphPage = page
          , glyphRow = row
          , glyphCol = col
          , glyphStyle = style
          , glyphSeed = documentSeed options + lineIndex * 1009 + col * 917
          }
      | (col, ch) <- zip [0 ..] text
      , ch /= '\f'
      ]

encodeDocumentJson :: Document -> String
encodeDocumentJson doc =
  "{"
    <> "\"format_version\":"
    <> show (documentFormatVersion doc)
    <> ",\"page\":"
    <> encodePage (documentPage doc)
    <> ",\"glyphs\":["
    <> commaJoin (map encodeGlyph (documentGlyphs doc))
    <> "]}"

encodePage :: PageSpec -> String
encodePage page =
  "{"
    <> "\"paper\":"
    <> quote (pagePaper page)
    <> ",\"columns\":"
    <> show (pageColumns page)
    <> ",\"rows\":"
    <> show (pageRows page)
    <> "}"

encodeGlyph :: Glyph -> String
encodeGlyph glyph =
  "{"
    <> "\"char\":"
    <> quote [glyphChar glyph]
    <> ",\"page\":"
    <> show (glyphPage glyph)
    <> ",\"row\":"
    <> show (glyphRow glyph)
    <> ",\"col\":"
    <> show (glyphCol glyph)
    <> ",\"style\":"
    <> quote (styleName (glyphStyle glyph))
    <> ",\"seed\":"
    <> show (glyphSeed glyph)
    <> "}"

styleName :: Style -> String
styleName NormalStyle = "normal"
styleName HeadingStyle = "heading"
styleName PreStyle = "pre"

quote :: String -> String
quote value = "\"" <> concatMap escape value <> "\""

escape :: Char -> String
escape '"' = "\\\""
escape '\\' = "\\\\"
escape '\n' = "\\n"
escape '\r' = "\\r"
escape '\t' = "\\t"
escape ch = [ch]

commaJoin :: [String] -> String
commaJoin [] = ""
commaJoin [x] = x
commaJoin (x : xs) = x <> "," <> commaJoin xs
