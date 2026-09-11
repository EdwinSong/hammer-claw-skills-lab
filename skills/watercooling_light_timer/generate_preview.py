from PIL import Image, ImageDraw, ImageFilter
import math
import os

W = H = 128
path = os.path.join(os.path.dirname(__file__), "preview.png")

img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
cx, cy = W // 2, H // 2

# --- glow ring ---
ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
rd = ImageDraw.Draw(ring)
for r_out, alpha in [(54, 60), (50, 140)]:
    rd.ellipse(
        (cx - r_out, cy - r_out, cx + r_out, cy + r_out),
        outline=(0, 229, 255, alpha),
        width=6,
    )
ring = ring.filter(ImageFilter.GaussianBlur(4))
img.alpha_composite(ring)

# crisp ring
d = ImageDraw.Draw(img)
d.ellipse((cx - 48, cy - 48, cx + 48, cy + 48), outline=(0, 229, 255, 255), width=4)

# hour ticks
for i in range(12):
    ang = math.radians(i * 30)
    r1, r2 = (40, 46) if i % 3 == 0 else (43, 46)
    w = 3 if i % 3 == 0 else 1
    x1 = cx + r1 * math.sin(ang)
    y1 = cy - r1 * math.cos(ang)
    x2 = cx + r2 * math.sin(ang)
    y2 = cy - r2 * math.cos(ang)
    d.line((x1, y1, x2, y2), fill=(0, 229, 255, 220), width=w)

# clock hands (9:00)
d.line((cx, cy, cx, cy - 32), fill=(255, 255, 255, 255), width=4)
d.line((cx, cy, cx - 24, cy), fill=(255, 255, 255, 255), width=3)
d.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=(255, 255, 255, 255))

# RGB arc at top
d.arc((cx - 44, cy - 44, cx + 44, cy + 44), start=200, end=340, fill=(255, 0, 176, 255), width=5)
d.arc((cx - 44, cy - 44, cx + 44, cy + 44), start=20, end=160, fill=(0, 229, 255, 255), width=5)

# bottom waves
for idx, (base_y, col) in enumerate(
    [(96, (0, 229, 255, 200)), (102, (168, 85, 247, 180)), (108, (236, 72, 153, 180))]
):
    pts = []
    for x in range(0, W, 2):
        y = base_y + int(3 * math.sin((x + idx * 20) / 14.0))
        pts.append((x, y))
    d.line(pts, fill=col, width=2)

# corner sparkles
for sx, sy in [(16, 16), (112, 16), (16, 112), (112, 112)]:
    d.line((sx - 4, sy, sx + 4, sy), fill=(255, 255, 255, 180), width=1)
    d.line((sx, sy - 4, sx, sy + 4), fill=(255, 255, 255, 180), width=1)

img.save(path)
print("saved", os.path.getsize(path), "bytes")
