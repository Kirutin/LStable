#!/usr/bin/env python3
"""Apply the Warehouse-13 palette without changing EFI asset geometry."""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent / "rEFInd-lesbian-singularity"
PINK = (255, 15, 84)
MAGENTA = (240, 24, 169)
VIOLET = (124, 85, 255)


def mix(first: tuple[int, int, int], second: tuple[int, int, int], amount: float):
    return tuple(round(a + (b - a) * amount) for a, b in zip(first, second))


def gradient(position: float) -> tuple[int, int, int]:
    if position <= 0.56:
        return mix(PINK, MAGENTA, position / 0.56)
    return mix(MAGENTA, VIOLET, (position - 0.56) / 0.44)


def recolor(path: Path, *, horizontal_gradient: bool) -> None:
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            luminance = (red * 54 + green * 183 + blue * 19) // 256
            color = gradient(x / max(1, width - 1)) if horizontal_gradient else PINK
            # Preserve antialiasing and intentional grey shading as brightness.
            pixels[x, y] = tuple(channel * luminance // 255 for channel in color) + (alpha,)
    image.save(path, optimize=True)


recolor(ROOT / "selection_big.png", horizontal_gradient=False)
recolor(ROOT / "selection_small.png", horizontal_gradient=True)
recolor(ROOT / "icons" / "os_debian.png", horizontal_gradient=True)
for name in (
    "arrow_left.png",
    "arrow_right.png",
    "func_about.png",
    "func_exit.png",
    "func_firmware.png",
    "func_reset.png",
    "func_shutdown.png",
    "tool_mok_tool.png",
):
    recolor(ROOT / "icons" / name, horizontal_gradient=True)
