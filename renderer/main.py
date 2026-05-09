import argparse
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


PAPER_SIZES_IN = {
    "letter": (8.5, 11.0),
}


def main():
    parser = argparse.ArgumentParser(
        description="Render typewriter glyph JSON to a raster PDF."
    )
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--dpi", type=int, default=300)
    parser.add_argument("--preset", default="light-typewriter")
    args = parser.parse_args()

    document = json.loads(args.input.read_text(encoding="utf-8"))
    pages = render_document(document, args.dpi, args.preset)
    save_pdf(pages, args.output, args.dpi)


def render_document(document, dpi, preset):
    page = document["page"]
    paper_width, paper_height = PAPER_SIZES_IN.get(
        page["paper"], PAPER_SIZES_IN["letter"]
    )
    width_px = round(paper_width * dpi)
    height_px = round(paper_height * dpi)
    columns = int(page["columns"])
    rows = int(page["rows"])
    margin_x = round(0.85 * dpi)
    margin_y = round(0.8 * dpi)
    usable_width = width_px - margin_x * 2
    usable_height = height_px - margin_y * 2
    cell_width = usable_width / max(columns, 1)
    line_height = usable_height / max(rows, 1)
    font_size = max(8, round(line_height * 0.68))
    font = load_font(font_size)
    max_page = max((glyph["page"] for glyph in document["glyphs"]), default=0)
    pages = [new_page(width_px, height_px) for _ in range(max_page + 1)]

    for glyph in document["glyphs"]:
        draw_glyph(
            pages[glyph["page"]],
            glyph,
            font,
            margin_x,
            margin_y,
            cell_width,
            line_height,
            dpi,
            preset,
        )

    return [page.convert("RGB") for page in pages]


def new_page(width_px, height_px):
    image = Image.new("RGBA", (width_px, height_px), (247, 243, 232, 255))
    pixels = image.load()
    rng = random.Random(982451653)
    for y in range(0, height_px, 3):
        for x in range(0, width_px, 3):
            delta = rng.randint(-2, 2)
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (clamp(r + delta), clamp(g + delta), clamp(b + delta), a)
    return image


def load_font(size):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/dejavu/DejaVuSansMono.ttf",
        "/run/current-system/sw/share/X11/fonts/TTF/DejaVuSansMono.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    return ImageFont.load_default(size=size)


def draw_glyph(
    page, glyph, font, margin_x, margin_y, cell_width, line_height, dpi, preset
):
    ch = glyph["char"]
    if ch == " ":
        return

    rng = random.Random(int(glyph["seed"]))
    style = glyph["style"]
    jitter = 0.0035 * dpi
    x = margin_x + glyph["col"] * cell_width + rng.uniform(-jitter, jitter)
    y = margin_y + glyph["row"] * line_height + rng.uniform(-jitter, jitter)
    ink = rng.randint(38, 92)
    if style == "heading":
        ink = rng.randint(18, 55)

    layer = Image.new("RGBA", page.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.text(
        (round(x), round(y)), ch, font=font, fill=(ink, ink, ink, rng.randint(190, 235))
    )

    if style == "heading" or rng.random() < 0.025:
        draw.text(
            (round(x + 0.0025 * dpi), round(y - 0.0015 * dpi)),
            ch,
            font=font,
            fill=(ink, ink, ink, 75),
        )

    if preset != "clean" and rng.random() < 0.08:
        layer = layer.filter(ImageFilter.GaussianBlur(radius=0.25))

    page.alpha_composite(layer)


def save_pdf(pages, output_path, dpi):
    output_path.parent.mkdir(parents=True, exist_ok=True)
    first, *rest = pages
    first.save(
        output_path, "PDF", resolution=float(dpi), save_all=True, append_images=rest
    )


def clamp(value):
    return max(0, min(255, value))


if __name__ == "__main__":
    main()
