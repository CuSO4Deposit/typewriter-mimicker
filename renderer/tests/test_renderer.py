import json
import subprocess
import sys
from pathlib import Path

RENDERER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RENDERER_ROOT))
from main import DEFAULT_PAPER_RGBA, EffectProfile, fit_font_size, resolve_font_path  # noqa: E402


def test_default_paper_is_nearly_white():
    assert DEFAULT_PAPER_RGBA == (252, 251, 247, 255)


def test_light_typewriter_profile_is_subtle():
    profile = EffectProfile.light_typewriter()

    assert profile.jitter_dpi_fraction == 0.0018
    assert profile.line_drift_dpi_fraction == 0.001
    assert profile.normal_ink_range[1] - profile.normal_ink_range[0] <= 30
    assert profile.blur_chance <= 0.025
    assert profile.pitch_scale < 1.0
    assert profile.ink_bleed_alpha == 56
    assert profile.ink_bleed_radius == 0.55
    assert profile.missing_ink_chance == 0.018


def test_clean_profile_has_no_ink_damage():
    profile = EffectProfile.clean()

    assert profile.ink_bleed_alpha == 0
    assert profile.missing_ink_chance == 0.0


def test_fit_font_size_respects_cell_width():
    font_size = fit_font_size(None, cell_width=9, line_height=18)

    assert font_size <= 12


def test_resolve_font_path_accepts_explicit_file(tmp_path):
    font_path = tmp_path / "SpecialElite-Regular.ttf"
    font_path.write_bytes(b"not a real font")

    assert resolve_font_path(str(font_path)) == font_path


def test_renderer_writes_nonempty_pdf(tmp_path):
    document = {
        "format_version": 1,
        "page": {"paper": "letter", "columns": 10, "rows": 4},
        "glyphs": [
            {"char": "H", "page": 0, "row": 0, "col": 0, "style": "heading", "seed": 1},
            {"char": "i", "page": 0, "row": 0, "col": 1, "style": "heading", "seed": 2},
            {"char": "O", "page": 0, "row": 2, "col": 0, "style": "normal", "seed": 3},
            {"char": "K", "page": 0, "row": 2, "col": 1, "style": "normal", "seed": 4},
        ],
    }
    input_path = tmp_path / "pages.json"
    output_path = tmp_path / "out.pdf"
    input_path.write_text(json.dumps(document), encoding="utf-8")

    subprocess.run(
        [
            sys.executable,
            str(RENDERER_ROOT / "main.py"),
            str(input_path),
            "--output",
            str(output_path),
            "--dpi",
            "72",
            "--preset",
            "clean",
        ],
        check=True,
    )

    assert output_path.exists()
    assert output_path.stat().st_size > 100
