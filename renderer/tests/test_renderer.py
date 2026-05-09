import json
import subprocess
import sys


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
            "main.py",
            str(input_path),
            "--output",
            str(output_path),
            "--dpi",
            "72",
        ],
        check=True,
    )

    assert output_path.exists()
    assert output_path.stat().st_size > 100
