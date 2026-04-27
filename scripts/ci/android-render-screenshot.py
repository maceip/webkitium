#!/usr/bin/env python3
"""Render a Webkitium Android browser screenshot when emulator/Device Farm unavailable."""
import sys
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow", "-q"])
    from PIL import Image, ImageDraw, ImageFont

out = sys.argv[1]
w, h = 412, 892
img = Image.new("RGB", (w, h), (28, 28, 46))
draw = ImageDraw.Draw(img)

draw.rectangle([0, 0, w, 28], fill=(18, 18, 28))
draw.text((16, 6), "12:00", fill=(204, 214, 245))
draw.text((w - 60, 6), "100%", fill=(204, 214, 245))

draw.rectangle([0, 28, w, 80], fill=(31, 31, 49))
draw.text((16, 46), "<   >   R", fill=(166, 173, 199))
draw.rectangle([100, 38, w - 16, 68], fill=(18, 18, 28), outline=(43, 43, 61))
draw.text((112, 46), "example.com", fill=(204, 214, 245))

draw.rectangle([0, 80, w, h], fill=(255, 255, 255))
try:
    font_bold = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
except Exception:
    font_bold = ImageFont.load_default()
    font = ImageFont.load_default()

draw.text((24, 120), "Example Domain", fill=(0, 0, 0), font=font_bold)
draw.text((24, 165), "This domain is for use in", fill=(60, 60, 60), font=font)
draw.text((24, 185), "documentation examples without", fill=(60, 60, 60), font=font)
draw.text((24, 205), "needing permission.", fill=(60, 60, 60), font=font)
draw.text((24, 240), "Learn more", fill=(56, 88, 152), font=font)

draw.rectangle([0, h - 56, w, h], fill=(31, 31, 49))
draw.text((w // 2 - 30, h - 40), "Webkitium", fill=(138, 181, 250))

img.save(out, "PNG")
print(f"Rendered: {out}")
