typewriter-mimicker
===================

Plain text to typewriter-style PDF.

The project has two deliberately separate stages.

1. formatter
  Haskell. Parses plain text conventions, wraps prose, preserves
  preformatted blocks, paginates a fixed-width page, and emits a
  deterministic glyph JSON model.

2. renderer
  Python. Reads the glyph model, rasterizes each glyph with light
  typewriter jitter and ink variation, adds a paper background, and
  writes a raster PDF. It also adds subtle line-level vertical drift
  to mimic small carriage return and paper advance variation.

The default renderer font is the bundled Special Elite typewriter face.
It is licensed under the Apache License 2.0. See:

    assets/fonts/SpecialElite-Apache-2.0.txt

Usage
-----

Enter the development shell:

    nix develop

Render in one command:

    nix run . -- examples/sample.txt .artifacts/sample.pdf

Render with optional aged paper:

    nix run . -- examples/sample.txt .artifacts/sample.pdf --paper aged

Options
-------

The one-command Nix app accepts renderer options after the output path:

    nix run . -- INPUT.txt OUTPUT.pdf --dpi 150 --paper aged

Formatter options:

  --cols N
  Number of fixed-width text columns. Default: 72.

  --rows N
  Number of text rows per page. Default: 58.

  --paper NAME
  Logical paper name in the JSON page model. Default: letter.

  --seed N
  Base seed for deterministic glyph effects. Default: 1.

Renderer options:

  --dpi N
  Output raster resolution. Default: 300.

  --preset NAME
  Visual effect preset. Default: light-typewriter.
  The clean preset disables jitter, line drift, ink bleed,
  and missing ink.

  --paper clean|aged
  Paper treatment. Default: clean.

  --font FONT.ttf
  Override the bundled Special Elite font.

Input syntax
------------

Plain lines are typed as written. Spaces are preserved exactly. A single
newline in the input becomes a newline on the page, and each blank input
line becomes one blank typewriter row. Lines longer than the configured
column width are split at the column boundary.

Use a form feed line to start a new page:

    \f

Indented blocks keep their spacing, bullets use "- " or "* ", and
Setext-style heading underlines use "====" or "----".

Generate glyph JSON:

    mkdir -p .artifacts
    stack --stack-yaml formatter/stack.yaml run -- examples/sample.txt \
      > .artifacts/pages.json

Render a PDF:

    uv --project renderer run python renderer/main.py \
      .artifacts/pages.json \
      --output .artifacts/sample.pdf \
      --dpi 150

Run checks:

    stack --stack-yaml formatter/stack.yaml test

    uv --project renderer run pytest
