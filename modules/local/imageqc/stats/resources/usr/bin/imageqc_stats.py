#!/usr/bin/env python3

import argparse
import math

import numpy as np
from PIL import Image


def luminance(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114])


def convolve(array, kernel):
    height, width = array.shape
    kernel_height, kernel_width = kernel.shape
    output = np.zeros((height - kernel_height + 1, width - kernel_width + 1))
    for y in range(kernel_height):
        for x in range(kernel_width):
            if kernel[y, x]:
                output += kernel[y, x] * array[
                    y : y + output.shape[0], x : x + output.shape[1]
                ]
    return output


def sharpness(lum):
    laplacian = np.array([[0, 1, 0], [1, -4, 1], [0, 1, 0]])
    return float(convolve(lum, laplacian).var())


def noise(lum):
    kernel = np.array([[1, -2, 1], [-2, 4, -2], [1, -2, 1]])
    height, width = lum.shape
    total = np.abs(convolve(lum, kernel)).sum()
    return float(total * math.sqrt(math.pi / 2) / (6 * (width - 2) * (height - 2)))


def colourfulness(rgb):
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    rg = red - green
    yb = (red + green) / 2 - blue
    spread = math.sqrt(rg.std() ** 2 + yb.std() ** 2)
    mean = math.sqrt(rg.mean() ** 2 + yb.mean() ** 2)
    return float(spread + 0.3 * mean)


def entropy(lum):
    counts = np.bincount(np.clip(lum, 0, 255).astype(np.uint8).ravel(), minlength=256)
    probabilities = counts[counts > 0] / counts.sum()
    return float(0.0 - (probabilities * np.log2(probabilities)).sum())


parser = argparse.ArgumentParser(description="Calculate basic statistics of an image.")
parser.add_argument("image")
parser.add_argument("--sample", required=True)
parser.add_argument("--output", required=True)
args = parser.parse_args()

rgb = np.asarray(Image.open(args.image).convert("RGB"), dtype=np.float64)
lum = luminance(rgb)

metrics = {
    "brightness": float(lum.mean()),
    "contrast": float(lum.std()),
    "shadow_clipping": float((rgb.max(axis=-1) <= 1).mean() * 100),
    "highlight_clipping": float((rgb.min(axis=-1) >= 254).mean() * 100),
    "sharpness": sharpness(lum),
    "noise": noise(lum),
    "colourfulness": colourfulness(rgb),
    "entropy": entropy(lum),
}

with open(args.output, "w") as f:
    f.write("\t".join(["Sample", *metrics]) + "\n")
    f.write("\t".join([args.sample, *(str(value) for value in metrics.values())]) + "\n")
