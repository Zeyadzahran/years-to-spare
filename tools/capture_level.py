#!/usr/bin/env python3
"""Ask Godot to render Level 01, then make an HTML gallery. No Python packages needed."""

import argparse
import html
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import quote


def main() -> int:
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--only", default="", help="Comma-separated capture name prefixes")
    parser.add_argument("--output", type=Path, default=project / "builds/level-review")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    # An explicit capture scene bypasses the main scene. Rendering needs a GPU;
    # --headless is useful for physics tests, but not these viewport images.
    command = [
        args.godot, "--path", str(project), "--windowed", "--resolution", "1280x720",
        "--audio-driver", "Dummy", "--log-file", str(output / "godot.log"),
        "--quit-after", "600", "tools/capture_production_greybox.tscn",
        "--", f"--output={output}", f"--only={args.only}",
    ]
    try:
        result = subprocess.run(command, text=True, capture_output=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"Capture failed: {error}", file=sys.stderr)
        return 1
    (output / "capture.log").write_text(result.stdout + result.stderr)
    images = [Path(line.removeprefix("CAPTURED ")) for line in result.stdout.splitlines()
              if line.startswith("CAPTURED ")]
    complete = f"CAPTURE_COMPLETE count={len(images)}"
    if result.returncode or not images or complete not in result.stdout.splitlines():
        print(f"Capture did not finish. See {output / 'capture.log'}", file=sys.stderr)
        return 1
    if any(path.parent != output or not path.is_file() for path in images):
        print("Capture reported a missing or unexpected image.", file=sys.stderr)
        return 1

    cards = []
    for path in images:
        label = html.escape(path.stem.replace("_", " "))
        url = quote(path.name)
        cards.append(f'<figure><a href="{url}"><img src="{url}" alt="{label}" loading="lazy"></a>'
                     f'<figcaption>{label}</figcaption></figure>')
    gallery = output / "index.html"
    gallery.write_text('''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Level 01 scene review</title>
<style>
body{margin:24px;background:#211c19;color:#f4e5d2;font:16px system-ui}
h1{font-size:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:20px}
figure{margin:0}img{width:100%;display:block}figcaption{padding:8px 0}
@media(max-width:480px){main{grid-template-columns:1fr}}
</style>
<h1>Level 01 scene review</h1>
<p>1280 × 720 at the gameplay camera zoom. Click an image to inspect it full size.
These are frozen scene views, not proof of a completed playthrough.</p>
<main>''' + "\n".join(cards) + "</main></html>\n")
    print(f"Captured {len(images)} images. Gallery: {gallery}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
