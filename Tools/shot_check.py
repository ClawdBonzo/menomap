#!/usr/bin/env python3
"""Is a simulator screenshot usable?  shot_check.py <shot.png> [<same frame 1.5 s later>]

Exit 0 when the screen below the status bar has content (not a blank launch frame) and, with a second shot, when the
two match (nothing still animating in). Exit 1 otherwise.
"""
import sys
from PIL import Image, ImageChops, ImageStat


def body(path):
    im = Image.open(path).convert("L")
    w, h = im.size
    return im.crop((int(w * 0.08), int(h * 0.10), int(w * 0.92), int(h * 0.92)))


a = body(sys.argv[1])
if ImageStat.Stat(a).stddev[0] < 6:  # a blank launch screen is one flat colour
    sys.exit(1)
if len(sys.argv) > 2:
    diff = ImageStat.Stat(ImageChops.difference(a, body(sys.argv[2]))).mean[0]
    if diff > 0.8:  # still fading or sliding in
        sys.exit(1)
sys.exit(0)
