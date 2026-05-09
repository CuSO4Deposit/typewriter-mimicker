typewriter-mimicker
===================

Plain text to typewriter-style PDF.

The project has two deliberately separate stages.

- formatter
  Haskell. Parses plain text conventions, wraps prose, preserves
  preformatted blocks, paginates a fixed-width page, and emits a
  deterministic glyph JSON model.

- renderer
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
