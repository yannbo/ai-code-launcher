#!/usr/bin/env python3
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


WIDTH = 1200
HEIGHT = 760
OUTPUT_PATH = Path("assets/dmg-background.png")


def vertical_gradient(top, bottom):
    image = Image.new("RGBA", (WIDTH, HEIGHT))
    pixels = image.load()
    for y in range(HEIGHT):
        ratio = y / (HEIGHT - 1)
        r = int(top[0] * (1 - ratio) + bottom[0] * ratio)
        g = int(top[1] * (1 - ratio) + bottom[1] * ratio)
        b = int(top[2] * (1 - ratio) + bottom[2] * ratio)
        for x in range(WIDTH):
            pixels[x, y] = (r, g, b, 255)
    return image


def main() -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    base = vertical_gradient((246, 228, 193), (213, 232, 241))
    draw = ImageDraw.Draw(base)

    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((40, 80, 540, 560), fill=(255, 197, 106, 145))
    glow_draw.ellipse((640, 140, 1160, 620), fill=(93, 175, 230, 120))
    glow_draw.rounded_rectangle((120, 110, 1080, 650), radius=48, outline=(255, 255, 255, 110), width=3)
    base = Image.alpha_composite(base, glow.filter(ImageFilter.GaussianBlur(48)))
    draw = ImageDraw.Draw(base)

    draw.rounded_rectangle((72, 72, WIDTH - 72, HEIGHT - 72), radius=54, outline=(255, 255, 255, 120), width=2)
    draw.rounded_rectangle((96, 96, WIDTH - 96, HEIGHT - 96), radius=42, outline=(255, 255, 255, 50), width=1)

    arrow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    arrow_draw = ImageDraw.Draw(arrow)
    arrow_points = [(515, 382), (720, 382), (720, 332), (860, 430), (720, 528), (720, 478), (515, 478)]
    arrow_draw.polygon(arrow_points, fill=(250, 250, 250, 205))
    arrow = arrow.filter(ImageFilter.GaussianBlur(2))
    base = Image.alpha_composite(base, arrow)
    draw = ImageDraw.Draw(base)

    draw.text((96, 124), "AI Code Launcher", fill=(33, 48, 69, 255))
    draw.text((98, 182), "Drag the app into Applications", fill=(52, 76, 102, 255))
    draw.text((98, 218), "Open projects fast, then launch Codex or Claude Code in one click.", fill=(69, 94, 120, 255))

    base.save(OUTPUT_PATH)
    print(f"Wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
