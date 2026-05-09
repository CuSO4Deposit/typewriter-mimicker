import argparse
import json
import os
import random
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


PAPER_SIZES_IN = {
    "letter": (8.5, 11.0),
}

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FONT = PROJECT_ROOT / "assets/fonts/SpecialElite-Regular.ttf"
DEFAULT_PAPER_RGBA = (252, 251, 247, 255)


@dataclass(frozen=True)
class EffectProfile:
    jitter_dpi_fraction: float
    normal_ink_range: tuple[int, int]
    heading_ink_range: tuple[int, int]
    alpha_range: tuple[int, int]
    double_strike_chance: float
    double_strike_alpha: int
    blur_chance: float
    blur_radius: float
    pitch_scale: float
    line_drift_dpi_fraction: float
    ink_bleed_alpha: int
    ink_bleed_radius: float
    missing_ink_chance: float
    missing_ink_radius: int

    @staticmethod
    def clean():
        return EffectProfile(
            jitter_dpi_fraction=0.0,
            normal_ink_range=(62, 72),
            heading_ink_range=(42, 52),
            alpha_range=(220, 230),
            double_strike_chance=0.0,
            double_strike_alpha=0,
            blur_chance=0.0,
            blur_radius=0.0,
            pitch_scale=0.92,
            line_drift_dpi_fraction=0.0,
            ink_bleed_alpha=0,
            ink_bleed_radius=0.0,
            missing_ink_chance=0.0,
            missing_ink_radius=0,
        )

    @staticmethod
    def light_typewriter():
        return EffectProfile(
            jitter_dpi_fraction=0.0018,
            normal_ink_range=(58, 82),
            heading_ink_range=(36, 58),
            alpha_range=(214, 232),
            double_strike_chance=0.01,
            double_strike_alpha=36,
            blur_chance=0.02,
            blur_radius=0.16,
            pitch_scale=0.92,
            line_drift_dpi_fraction=0.001,
            ink_bleed_alpha=56,
            ink_bleed_radius=0.55,
            missing_ink_chance=0.018,
            missing_ink_radius=1,
        )


def main():
    parser = argparse.ArgumentParser(
        description="Render typewriter glyph JSON to a raster PDF."
    )
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--dpi", type=int, default=300)
    parser.add_argument("--preset", default="light-typewriter")
    parser.add_argument("--font", help="Path to a TTF/OTF font file.")
    args = parser.parse_args()

    document = json.loads(args.input.read_text(encoding="utf-8"))
    pages = render_document(document, args.dpi, args.preset, args.font)
    save_pdf(pages, args.output, args.dpi)


def render_document(document, dpi, preset, font_name=None):
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
    cell_width = (usable_width / max(columns, 1)) * effect_profile(preset).pitch_scale
    line_height = usable_height / max(rows, 1)
    font_path = resolve_font_path(font_name)
    font_size = fit_font_size(font_path, cell_width, line_height)
    font = load_font(font_size, font_path)
    profile = effect_profile(preset)
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
            profile,
        )

    return [page.convert("RGB") for page in pages]


def new_page(width_px, height_px):
    image = Image.new("RGBA", (width_px, height_px), DEFAULT_PAPER_RGBA)
    pixels = image.load()
    rng = random.Random(982451653)
    for y in range(0, height_px, 3):
        for x in range(0, width_px, 3):
            delta = rng.randint(-2, 2)
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (clamp(r + delta), clamp(g + delta), clamp(b + delta), a)
    return image


def effect_profile(preset):
    if preset == "clean":
        return EffectProfile.clean()
    return EffectProfile.light_typewriter()


def resolve_font_path(font_name=None):
    if font_name:
        requested = Path(font_name).expanduser()
        if requested.exists():
            return requested

    env_font = os.environ.get("TYPEWRITER_FONT")
    if env_font:
        requested = Path(env_font).expanduser()
        if requested.exists():
            return requested

    if DEFAULT_FONT.exists():
        return DEFAULT_FONT

    candidates = [
        "/usr/share/fonts/truetype/special-elite/SpecialElite-Regular.ttf",
        "/usr/share/fonts/truetype/courier-prime/CourierPrime-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/dejavu/DejaVuSansMono.ttf",
        "/run/current-system/sw/share/X11/fonts/TTF/DejaVuSansMono.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return Path(candidate)
    return None


def fit_font_size(font_path, cell_width, line_height):
    size = max(8, round(line_height * 0.62))
    sample = "MW"
    while size > 6:
        font = load_font(size, font_path)
        bbox = font.getbbox(sample)
        glyph_width = (bbox[2] - bbox[0]) / len(sample)
        glyph_height = bbox[3] - bbox[1]
        if glyph_width <= cell_width * 0.92 and glyph_height <= line_height * 0.82:
            return size
        size -= 1
    return size


def load_font(size, font_path):
    if font_path is not None:
        return ImageFont.truetype(font_path, size=size)
    return ImageFont.load_default(size=size)


def draw_glyph(
    page, glyph, font, margin_x, margin_y, cell_width, line_height, dpi, profile
):
    ch = glyph["char"]
    if ch == " ":
        return

    rng = random.Random(int(glyph["seed"]))
    style = glyph["style"]
    jitter = profile.jitter_dpi_fraction * dpi
    line_drift = line_drift_for(glyph, dpi, profile)
    x = margin_x + glyph["col"] * cell_width + rng.uniform(-jitter, jitter)
    y = (
        margin_y
        + glyph["row"] * line_height
        + line_drift
        + rng.uniform(-jitter, jitter)
    )
    ink = rng.randint(*profile.normal_ink_range)
    if style == "heading":
        ink = rng.randint(*profile.heading_ink_range)

    padding = max(4, round(0.03 * dpi))
    tile_width = max(round(cell_width + padding * 2), font.getbbox(ch)[2] + padding * 2)
    tile_height = max(
        round(line_height + padding * 2), font.getbbox(ch)[3] + padding * 2
    )
    origin_x = round(x - padding)
    origin_y = round(y - padding)
    local_x = round(x - origin_x)
    local_y = round(y - origin_y)

    layer = Image.new("RGBA", (tile_width, tile_height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.text(
        (local_x, local_y),
        ch,
        font=font,
        fill=(ink, ink, ink, rng.randint(*profile.alpha_range)),
    )

    if style == "heading" or rng.random() < profile.double_strike_chance:
        draw.text(
            (round(local_x + 0.0012 * dpi), round(local_y - 0.0008 * dpi)),
            ch,
            font=font,
            fill=(ink, ink, ink, profile.double_strike_alpha),
        )

    if rng.random() < profile.blur_chance:
        layer = layer.filter(ImageFilter.GaussianBlur(radius=profile.blur_radius))

    layer = apply_missing_ink(layer, glyph, profile)
    page.alpha_composite(
        ink_bleed_layer(layer, profile, ink), dest=(origin_x, origin_y)
    )
    page.alpha_composite(layer, dest=(origin_x, origin_y))


def line_drift_for(glyph, dpi, profile):
    max_drift = profile.line_drift_dpi_fraction * dpi
    rng = random.Random((glyph["page"] + 1) * 1000003 + glyph["row"] * 9176)
    return rng.uniform(-max_drift, max_drift)


def ink_bleed_layer(layer, profile, ink):
    if profile.ink_bleed_alpha <= 0:
        return Image.new("RGBA", layer.size, (0, 0, 0, 0))

    alpha = layer.getchannel("A").filter(
        ImageFilter.GaussianBlur(radius=profile.ink_bleed_radius)
    )
    alpha = alpha.point(lambda value: min(value, profile.ink_bleed_alpha))
    bleed = Image.new("RGBA", layer.size, (ink, ink, ink, 0))
    bleed.putalpha(alpha)
    return bleed


def apply_missing_ink(layer, glyph, profile):
    if profile.missing_ink_chance <= 0:
        return layer

    damaged = layer.copy()
    alpha = damaged.getchannel("A")
    draw = ImageDraw.Draw(alpha)
    rng = random.Random(int(glyph["seed"]) + 424242)
    bbox = alpha.getbbox()
    if bbox is None:
        return damaged

    left, top, right, bottom = bbox
    area = max(1, (right - left) * (bottom - top))
    holes = max(1, round(area * profile.missing_ink_chance / 100))
    radius = profile.missing_ink_radius
    for _ in range(holes):
        x = rng.randint(left, max(left, right - 1))
        y = rng.randint(top, max(top, bottom - 1))
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=0)

    damaged.putalpha(alpha)
    return damaged


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
