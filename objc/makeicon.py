#!/usr/bin/env python3
"""生成 RepoStore 应用图标：深色渐变底 + 圆角卡片堆叠 + 下载箭头"""
from PIL import Image, ImageDraw, ImageFilter
import os

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "RS/Resources/Assets.xcassets/AppIcon.appiconset")

C1 = (91, 124, 250)
C2 = (155, 107, 255)
BG1 = (16, 19, 32)
BG2 = (28, 24, 56)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def diag_gradient(size, c1, c2):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2.0 * (size - 1))
            px[x, y] = lerp(c1, c2, t)
    return img


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1],
                                        radius=radius, fill=255)
    return m


def main():
    base = diag_gradient(S, BG1, BG2).convert("RGBA")

    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = S // 2, int(S * 0.46)
    r = int(S * 0.52)
    for i in range(60, 0, -1):
        t = i / 60.0
        rr = int(r * t)
        alpha = int(70 * (1 - t) ** 2)
        gd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr],
                   fill=lerp(C1, C2, 0.5) + (alpha,))
    base = Image.alpha_composite(base, glow.filter(ImageFilter.GaussianBlur(S * 0.06)))

    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    card_w, card_h = int(S * 0.50), int(S * 0.62)
    cx, cy = S // 2, int(S * 0.53)

    def card(ox, oy, scale, alpha):
        w, h = int(card_w * scale), int(card_h * scale)
        x0, y0 = cx - w // 2 + ox, cy - h // 2 + oy
        ld.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=int(w * 0.22),
                             fill=(255, 255, 255, alpha))

    card(-int(S * 0.085), -int(S * 0.035), 0.90, 55)
    card(int(S * 0.085), -int(S * 0.035), 0.90, 55)

    fw, fh = card_w, card_h
    fx, fy = cx - fw // 2, cy - fh // 2
    grad = diag_gradient(fw, C1, C2).convert("RGBA")
    grad.putalpha(rounded_mask(fw, int(fw * 0.22)))
    layer.alpha_composite(grad, (fx, fy))
    ld.rounded_rectangle([fx, fy, fx + fw, fy + fh], radius=int(fw * 0.22),
                         outline=(255, 255, 255, 90), width=max(2, S // 300))
    base = Image.alpha_composite(base, layer)

    ar = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ad = ImageDraw.Draw(ar)
    acx, acy = cx, cy + int(S * 0.005)
    aw, shaft = int(S * 0.115), int(S * 0.135)
    lw = max(6, int(S * 0.030))
    white = (255, 255, 255, 255)
    ad.rounded_rectangle([acx - lw // 2, acy - shaft // 2,
                          acx + lw // 2, acy + shaft // 2],
                         radius=lw // 2, fill=white)
    tip_y = acy + shaft // 2 + int(S * 0.012)
    ad.line([(acx - aw // 2, tip_y - int(S * 0.055)), (acx, tip_y),
             (acx + aw // 2, tip_y - int(S * 0.055))],
            fill=white, width=lw, joint="curve")
    base_y = acy + shaft // 2 + int(S * 0.075)
    tray_w = int(S * 0.155)
    ad.rounded_rectangle([acx - tray_w // 2, base_y - lw // 2,
                          acx + tray_w // 2, base_y + lw // 2],
                         radius=lw // 2, fill=white)
    base = Image.alpha_composite(base, ar)

    os.makedirs(OUT, exist_ok=True)
    sizes = [("icon-20@2x.png", 40), ("icon-20@3x.png", 60),
             ("icon-29@2x.png", 58), ("icon-29@3x.png", 87),
             ("icon-40@2x.png", 80), ("icon-40@3x.png", 120),
             ("icon-60@2x.png", 120), ("icon-60@3x.png", 180),
             ("icon-76@2x.png", 152), ("icon-83.5@2x.png", 167),
             ("icon-1024.png", 1024)]
    for name, sz in sizes:
        base.convert("RGB").resize((sz, sz), Image.LANCZOS).save(
            os.path.join(OUT, name), "PNG")
        print("wrote", name, sz)
    base.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(
        os.path.join(os.path.dirname(OUT), "AppIcon.png"), "PNG")


if __name__ == "__main__":
    main()
