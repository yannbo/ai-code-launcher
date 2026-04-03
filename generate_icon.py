#!/usr/bin/env python3
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


SIZE = 1024
OUTPUT_PATH = Path("assets/app-icon.png")
TIFF_OUTPUT_PATH = Path("assets/app-icon.tiff")


def rounded_gradient_background() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pixels = image.load()
    top = (247, 179, 91)
    bottom = (33, 58, 92)

    for y in range(SIZE):
        ratio = y / (SIZE - 1)
        r = int(top[0] * (1 - ratio) + bottom[0] * ratio)
        g = int(top[1] * (1 - ratio) + bottom[1] * ratio)
        b = int(top[2] * (1 - ratio) + bottom[2] * ratio)
        for x in range(SIZE):
            pixels[x, y] = (r, g, b, 255)

    mask = Image.new("L", (SIZE, SIZE), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((32, 32, SIZE - 32, SIZE - 32), radius=230, fill=255)
    image.putalpha(mask)
    return image


def add_glow(base: Image.Image) -> Image.Image:
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    draw.ellipse((150, 90, 880, 720), fill=(255, 230, 170, 70))
    draw.ellipse((220, 350, 930, 980), fill=(94, 205, 255, 75))
    return Image.alpha_composite(base, glow.filter(ImageFilter.GaussianBlur(60)))


def draw_folder(draw: ImageDraw.ImageDraw) -> None:
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((170, 275, 854, 760), radius=130, fill=(8, 16, 32, 95))
    shadow_draw.rounded_rectangle((210, 225, 530, 360), radius=70, fill=(8, 16, 32, 80))
    shadow_blur = shadow.filter(ImageFilter.GaussianBlur(28))
    draw._image.alpha_composite(shadow_blur)  # type: ignore[attr-defined]

    draw.rounded_rectangle((180, 250, 530, 410), radius=82, fill=(255, 212, 120, 255))
    draw.rounded_rectangle((150, 320, 874, 780), radius=135, fill=(255, 188, 72, 255))
    draw.rounded_rectangle((180, 360, 844, 742), radius=110, fill=(255, 205, 110, 255))


def draw_terminal(draw: ImageDraw.ImageDraw) -> None:
    panel = (265, 425, 760, 720)
    draw.rounded_rectangle(panel, radius=92, fill=(17, 31, 50, 255))
    draw.rounded_rectangle((285, 445, 740, 700), radius=76, fill=(24, 44, 68, 255))

    for index, color in enumerate([(255, 110, 89, 255), (255, 208, 95, 255), (88, 217, 131, 255)]):
        left = 320 + index * 52
        draw.ellipse((left, 472, left + 28, 500), fill=color)

    arrow = [(360, 545), (425, 600), (360, 655)]
    draw.line(arrow, fill=(255, 236, 199, 255), width=30, joint="curve")
    draw.line((470, 646, 615, 646), fill=(110, 230, 255, 255), width=28)
    draw.rounded_rectangle((640, 560, 680, 690), radius=18, fill=(255, 236, 199, 255))


def add_highlights(base: Image.Image) -> Image.Image:
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.rounded_rectangle((100, 72, 924, 924), radius=210, outline=(255, 255, 255, 72), width=10)
    draw.arc((90, 40, 934, 540), start=200, end=335, fill=(255, 255, 255, 72), width=12)
    return Image.alpha_composite(base, overlay)


def main() -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    base = rounded_gradient_background()
    base = add_glow(base)
    draw = ImageDraw.Draw(base)
    draw_folder(draw)
    draw_terminal(draw)
    base = add_highlights(base)
    base.save(OUTPUT_PATH)
    tiff_sizes = [16, 32, 48, 128, 256, 512, 1024]
    tiff_frames = [base.resize((size, size), Image.Resampling.LANCZOS) for size in tiff_sizes]
    tiff_frames[0].save(TIFF_OUTPUT_PATH, save_all=True, append_images=tiff_frames[1:])
    print(f"Wrote {OUTPUT_PATH}")
    print(f"Wrote {TIFF_OUTPUT_PATH}")


if __name__ == "__main__":
    main()
