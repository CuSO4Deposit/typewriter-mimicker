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
  writes a raster PDF.

The default renderer font is the bundled Special Elite typewriter face.
It is licensed under the SIL Open Font License. See:

    assets/fonts/SpecialElite-OFL.txt

Usage
-----

Enter the development shell:

    nix develop

Generate glyph JSON:

    cd formatter
    stack run -- ../examples/sample.txt > ../.artifacts/pages.json

Render a PDF:

    cd renderer
    uv run python main.py ../.artifacts/pages.json \
      --output ../.artifacts/sample.pdf \
      --dpi 150

Run checks:

    cd formatter
    stack test

    cd renderer
    uv run pytest
