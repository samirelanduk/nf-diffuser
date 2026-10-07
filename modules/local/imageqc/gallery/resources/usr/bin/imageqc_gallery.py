#!/usr/bin/env python3

import argparse
import base64
import html
import io
import json

from PIL import Image

SETTINGS = [
    ("width", "Width"),
    ("height", "Height"),
    ("steps", "Steps"),
    ("cfg", "CFG"),
    ("sampler", "Sampler"),
    ("schedule", "Schedule"),
]

STYLE = """<style>
.imageqc-gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 1rem; }
.imageqc-card { border: 1px solid #dee2e6; border-radius: .375rem; padding: .5rem; display: flex; flex-direction: column; gap: .25rem; }
.imageqc-card img { width: 100%; height: auto; border-radius: .25rem; }
</style>"""

parser = argparse.ArgumentParser(description="Build an HTML thumbnail gallery of images and their prompts.")
parser.add_argument("samples", help="JSON list of sample meta maps, each with an image file name")
parser.add_argument("--thumbnail-size", type=int, default=256)
parser.add_argument("--output", required=True)
args = parser.parse_args()


def thumbnail(path):
    image = Image.open(path).convert("RGB")
    image.thumbnail((args.thumbnail_size, args.thumbnail_size))
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=80)
    return base64.b64encode(buffer.getvalue()).decode()


def card(sample):
    settings = " · ".join(
        f"{label} {html.escape(str(sample[key]))}"
        for key, label in SETTINGS
        if sample.get(key) not in (None, "")
    )
    negative = (
        f"<div class='small text-muted'><b>Negative:</b> {html.escape(sample['negative_prompt'])}</div>"
        if sample.get("negative_prompt")
        else ""
    )
    return (
        "<div class='imageqc-card'>"
        f"<img src='data:image/jpeg;base64,{thumbnail(sample['image'])}' alt='{html.escape(sample['id'])}'>"
        f"<b>{html.escape(sample['id'])}</b>"
        f"<div class='small'>{html.escape(sample.get('prompt') or '')}</div>"
        f"{negative}"
        f"<div class='small text-muted'>{settings}</div>"
        "</div>"
    )


with open(args.samples) as f:
    samples = json.load(f)

with open(args.output, "w") as f:
    f.write(STYLE)
    f.write("<div class='imageqc-gallery'>")
    f.write("".join(card(sample) for sample in samples))
    f.write("</div>\n")
