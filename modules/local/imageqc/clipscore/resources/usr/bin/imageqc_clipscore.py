#!/usr/bin/env python3

import argparse

import torch
from PIL import Image
from transformers import CLIPModel, CLIPProcessor

parser = argparse.ArgumentParser(
    description="Score how well an image matches its prompt and negative prompt with a CLIP model."
)
parser.add_argument("image")
parser.add_argument("model")
parser.add_argument("--sample", required=True)
parser.add_argument("--prompt", required=True)
parser.add_argument("--negative-prompt", default="")
parser.add_argument("--name", default="clipscore")
parser.add_argument("--logit-scale", action="store_true")
parser.add_argument("--threads", type=int, default=1)
parser.add_argument("--output", required=True)
args = parser.parse_args()

torch.set_num_threads(args.threads)
model = CLIPModel.from_pretrained(args.model).eval()
processor = CLIPProcessor.from_pretrained(args.model)

texts = [args.prompt] + ([args.negative_prompt] if args.negative_prompt else [])
inputs = processor(
    text=texts,
    images=Image.open(args.image).convert("RGB"),
    return_tensors="pt",
    padding=True,
    truncation=True,
    max_length=model.config.text_config.max_position_embeddings,
)
with torch.no_grad():
    outputs = model(**inputs)
similarities = (outputs.image_embeds @ outputs.text_embeds.T)[0]

if args.logit_scale:
    scores = (model.logit_scale.exp() * similarities).tolist()
else:
    scores = (100 * similarities).clamp(min=0).tolist()

metrics = {args.name: scores[0]}
if args.negative_prompt:
    metrics[f"{args.name}_negative"] = scores[1]

with open(args.output, "w") as f:
    f.write("\t".join(["Sample", *metrics]) + "\n")
    f.write("\t".join([args.sample, *(str(value) for value in metrics.values())]) + "\n")
