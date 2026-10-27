"""Habillage de l'assistant d'installation de Chroniques.

Inno Setup n'accepte que des bitmaps : pas de degrade, pas de transparence,
pas de police a lui donner. Tout ce qui fait l'allure de l'assistant doit
donc etre peint ici, puis exporte en BMP 24 bits.

    python installer/assets/make_wizard_art.py

Produit, dans ce dossier :
    banner.bmp / banner@2x.bmp   le bandeau gauche des pages d'accueil et de
                                 fin (164x314 au rapport 1, double au 2)
    small.bmp  / small@2x.bmp    la vignette en haut des autres pages
    anim00..anim17.bmp           les images de l'animation du bandeau
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

# Rendu interne, reduit ensuite : les bords restent nets.
SS = 3

BANNER = (164, 314)
SMALL = (55, 58)
FRAMES = 18

ACCENT = (74, 144, 217)
SKY = (104, 176, 240)
DEEP = (12, 30, 62)
PAPER = (255, 255, 255)
WARM = (255, 230, 176)


def mix(c1, c2, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c1, c2))


def font(size, bold=False):
    names = ('segoeuib.ttf', 'arialbd.ttf') if bold else ('segoeui.ttf',
                                                          'arial.ttf')
    for name in names:
        path = os.path.join(os.environ.get('WINDIR', r'C:\Windows'), 'Fonts',
                            name)
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def vertical_gradient(size, top, bottom, power=1.0):
    w, h = size
    t = (np.linspace(0, 1, h) ** power).reshape(-1, 1)
    arr = np.empty((h, w, 3), np.float64)
    for i in range(3):
        arr[..., i] = top[i] + (bottom[i] - top[i]) * t
    return Image.fromarray(arr.astype(np.uint8), 'RGB')


def radial_glow(size, cx, cy, radius, color, peak=200, power=2.0):
    """Halo doux, rendu en calque a composer."""
    w, h = size
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / max(radius, 1)
    a = (np.clip(1 - d, 0, 1) ** power * peak).astype(np.uint8)
    layer = Image.new('RGBA', (w, h), color + (0,))
    layer.putalpha(Image.fromarray(a, 'L'))
    return layer


def star(draw, cx, cy, r, fill, waist=0.30, rot=0.0):
    pts = []
    for k in range(8):
        ang = math.radians(-90 + 45 * k + rot)
        rr = r if k % 2 == 0 else r * waist
        pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
    draw.polygon(pts, fill=fill)


def book_glyph(size):
    """Le livre ouvert, le meme signe que dans l'application."""
    w = size
    img = Image.new('RGBA', (w, w), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = w / 100.0

    def bez(p0, p1, p2, steps=40):
        out = []
        for i in range(steps + 1):
            t = i / steps
            m = 1 - t
            out.append((m * m * p0[0] + 2 * m * t * p1[0] + t * t * p2[0],
                        m * m * p0[1] + 2 * m * t * p1[1] + t * t * p2[1]))
        return out

    left = bez((10 * u, 26 * u), (30 * u, 16 * u), (48 * u, 25 * u)) + \
        bez((48 * u, 78 * u), (30 * u, 70 * u), (10 * u, 80 * u))
    right = bez((52 * u, 25 * u), (70 * u, 16 * u), (90 * u, 26 * u)) + \
        bez((90 * u, 80 * u), (70 * u, 70 * u), (52 * u, 78 * u))
    d.polygon(left, fill=PAPER + (255,))
    d.polygon(right, fill=PAPER + (255,))
    # La reliure, creusee.
    d.rectangle([49 * u, 25 * u, 51 * u, 78 * u],
                fill=mix(ACCENT, (0, 0, 0), 0.35) + (150,))
    return img


def paint_banner(phase=None):
    """Le bandeau. [phase] anime les etincelles et le voile de lumiere."""
    w, h = BANNER[0] * SS, BANNER[1] * SS
    img = vertical_gradient((w, h), SKY, DEEP, power=0.85).convert('RGBA')

    # Une lueur chaude monte du bas, comme la boite de l'ecran d'ouverture.
    img.alpha_composite(radial_glow((w, h), w * 0.5, h * 1.02, h * 0.55,
                                    ACCENT, peak=120))

    if phase is not None:
        # Voile de lumiere qui traverse lentement : c'est lui qui donne
        # l'impression que l'image respire, sans rien faire bouger de net.
        sweep = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        sy = int((phase * 1.6 - 0.3) * h)
        ImageDraw.Draw(sweep).ellipse(
            [-w * 0.6, sy - h * 0.16, w * 1.6, sy + h * 0.16],
            fill=(255, 255, 255, 42))
        img.alpha_composite(sweep.filter(ImageFilter.GaussianBlur(w * 0.10)))

    glyph_size = int(w * 0.42)
    glyph = book_glyph(glyph_size)
    gx, gy = (w - glyph_size) // 2, int(h * 0.20)
    img.alpha_composite(radial_glow((w, h), w * 0.5, gy + glyph_size * 0.5,
                                    glyph_size * 1.5, (255, 255, 255),
                                    peak=58))
    img.alpha_composite(glyph, (gx, gy))

    # Les etincelles : elles derivent vers le haut et s'eteignent.
    spark = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(spark)
    # Elles derivent entre le livre et le titre, jamais dessus : une
    # etincelle qui traverse le mot le rend illisible.
    seeds = [(0.26, 0.60, 0.030, 0.0), (0.74, 0.62, 0.022, 0.35),
             (0.46, 0.63, 0.026, 0.62), (0.62, 0.61, 0.018, 0.15),
             (0.36, 0.64, 0.020, 0.80)]
    for fx, fy, fr, off in seeds:
        t = ((phase or 0.0) + off) % 1.0
        y = (fy - t * 0.20) * h
        alpha = int(235 * math.sin(math.pi * t) ** 0.7)
        if alpha <= 2:
            continue
        star(d, fx * w, y, fr * w * (0.7 + 0.5 * math.sin(math.pi * t)),
             WARM + (alpha,), rot=t * 90)
    img.alpha_composite(spark)

    # Le nom, pose en bas.
    d = ImageDraw.Draw(img)
    title = font(int(w * 0.135), bold=True)
    sub = font(int(w * 0.055))
    d.text((w * 0.5, h * 0.705), 'Chroniques', font=title, fill=PAPER + (255,),
           anchor='mm')
    d.text((w * 0.5, h * 0.760), 'T H E   S T O R Y   B O X', font=sub,
           anchor='mm', fill=mix(PAPER, SKY, 0.45) + (235,))

    # Un filet d'accent, pour fermer la composition.
    d.rectangle([w * 0.5 - w * 0.09, h * 0.800, w * 0.5 + w * 0.09,
                 h * 0.800 + SS], fill=mix(ACCENT, PAPER, 0.3) + (200,))

    return img.convert('RGB').resize(BANNER, Image.LANCZOS)


def paint_small():
    """La vignette des pages suivantes : la tuile de l'application."""
    w = SMALL[0] * SS * 2
    img = Image.new('RGBA', (w, w), (0, 0, 0, 0))
    tile = vertical_gradient((w, w), SKY, mix(DEEP, ACCENT, 0.35)).convert(
        'RGBA')
    mask = Image.new('L', (w, w), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, w - 1],
                                           radius=int(w * 0.24), fill=255)
    img.paste(tile, (0, 0), mask)

    g = int(w * 0.56)
    img.alpha_composite(book_glyph(g), ((w - g) // 2, (w - g) // 2))

    out = Image.new('RGB', SMALL, DEEP)
    art = img.convert('RGB').resize((SMALL[1], SMALL[1]), Image.LANCZOS)
    out.paste(art, ((SMALL[0] - SMALL[1]) // 2, 0))
    return out


def save(img, name, scale=1):
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale),
                         Image.LANCZOS)
    img.save(os.path.join(HERE, name))


if __name__ == '__main__':
    banner = paint_banner()
    save(banner, 'banner.bmp')
    save(paint_banner(), 'banner@2x.bmp', scale=2)

    small = paint_small()
    save(small, 'small.bmp')
    save(small, 'small@2x.bmp', scale=2)

    for i in range(FRAMES):
        save(paint_banner(phase=i / FRAMES), f'anim{i:02d}.bmp')

    print(f'habillage genere dans {HERE} ({FRAMES} images d animation)')
