"""Draw the Cycle Timer app icon with simple geometric shapes."""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "Assets.xcassets" / "AppIcon.appiconset"
ICON_DIR.mkdir(parents=True, exist_ok=True)

scale = 4
image = Image.new("RGB", (1024 * scale, 1024 * scale), "#FEFBF6")
draw = ImageDraw.Draw(image)


def box(*coords):
    return tuple(int(value * scale) for value in coords)


draw.ellipse(box(128, 128, 896, 896), fill="#E9F1E2")
draw.ellipse(box(203, 203, 821, 821), fill="#FFFFFF")
draw.arc(box(240, 240, 784, 784), 38, 312, fill="#14A89C", width=57 * scale)
draw.ellipse(box(472, 472, 552, 552), fill="#303D2E")
draw.rounded_rectangle(box(486, 311, 538, 522), radius=26 * scale, fill="#303D2E")
draw.polygon(
    [(505 * scale, 489 * scale), (533 * scale, 536 * scale),
     (660 * scale, 461 * scale), (633 * scale, 415 * scale)],
    fill="#303D2E",
)
draw.ellipse(box(644, 261, 782, 399), fill="#CFA35C")
draw.ellipse(box(673, 290, 753, 370), fill="#FEFBF6")

image.resize((1024, 1024), Image.Resampling.LANCZOS).save(ICON_DIR / "AppIcon.png", optimize=True)
(ICON_DIR / "Contents.json").write_text(
    '{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}\n'
)
print(ICON_DIR / "AppIcon.png")
