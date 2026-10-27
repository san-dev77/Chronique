"""Generateur des pistes de logo de Chroniques.

Tout est trace trois fois plus grand puis reduit : c'est ce qui donne des
bords lisses la ou un trace direct laisserait des escaliers. Rien d'autre que
Pillow et numpy.

    python design/logo/make_logo.py

Les reglages qui comptent sont en haut de fichier : teintes, profondeur du
degrade, epaisseurs. Une piste retenue s'ajuste ici, sans tout refaire.
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

SIZE = 512          # cote de la marque finale
SS = 3              # surechantillonnage
N = SIZE * SS

ACCENT = (74, 144, 217)            # #4A90D9, l'accent de l'application
TILE_TOP = (104, 176, 240)         # le ciel, en haut a gauche
TILE_BOTTOM = (31, 78, 138)        # la profondeur, en bas a droite
PAPER = (255, 255, 255)
PAPER_SHADE = (222, 234, 248)      # le papier dans l'ombre
WARM = (255, 228, 168)             # la lumiere gardee dans la boite


# ------------------------------------------------------------------ outils

def mix(c1, c2, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c1, c2))


def px(v):
    """Coordonnee relative (0..1) vers pixels de la toile agrandie."""
    return v * N


def linear_gradient(c1, c2, angle_deg=128):
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)
    a = math.radians(angle_deg)
    t = x * math.cos(a) + y * math.sin(a)
    t = (t - t.min()) / (t.max() - t.min())
    arr = np.empty((N, N, 3), np.float64)
    for i in range(3):
        arr[..., i] = c1[i] + (c2[i] - c1[i]) * t
    return Image.fromarray(arr.astype(np.uint8), "RGB")


def squircle_mask(radius=0.225):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, N - 1, N - 1], radius=px(radius), fill=255)
    return m


def radial_alpha(cx, cy, r, peak=255, power=2.2):
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)
    d = np.sqrt((x - px(cx)) ** 2 + (y - px(cy)) ** 2) / px(r)
    return Image.fromarray(
        (np.clip(1.0 - d, 0, 1) ** power * peak).astype(np.uint8), "L")


def star4(draw, cx, cy, r, fill, waist=0.30, rot=0.0):
    pts = []
    for k in range(8):
        ang = math.radians(-90 + 45 * k + rot)
        rr = r if k % 2 == 0 else r * waist
        pts.append((px(cx) + math.cos(ang) * px(rr),
                    px(cy) + math.sin(ang) * px(rr)))
    draw.polygon(pts, fill=fill)


def rotate_pts(pts, cx, cy, deg):
    a = math.radians(deg)
    return [(cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a),
             cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a))
            for x, y in pts]


def alpha_mask(layer):
    return layer.split()[3]


def shadow_of(layer, dx, dy, blur, alpha, color=(10, 32, 64)):
    """Ombre portee calculee depuis la silhouette d'un calque.

    C'est ce qui separe une forme posee sur un fond d'une forme qui repose
    dessus : sans elle, la marque flotte.
    """
    a = alpha_mask(layer).point(lambda v: int(v * alpha / 255))
    sh = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    sh.paste(Image.new("RGB", (N, N), color), (0, 0), a)
    sh = sh.filter(ImageFilter.GaussianBlur(px(blur)))
    return sh.transform(sh.size, Image.AFFINE,
                        (1, 0, -px(dx), 0, 1, -px(dy)))


def paper_gradient(mask, top=PAPER, bottom=PAPER_SHADE, angle=108):
    """Le blanc n'est jamais plat : un degrade tres court suffit a donner de
    la matiere au papier."""
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.paste(linear_gradient(top, bottom, angle), (0, 0), mask)
    return out


def tile():
    """La tuile commune : degrade profond, vignette, reflet, et un cheveu de
    lumiere sur l'arete haute."""
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    mask = squircle_mask()
    img.paste(linear_gradient(TILE_TOP, TILE_BOTTOM, 118), (0, 0), mask)

    # Vignette : les angles s'enfoncent, ce qui fait avancer le centre.
    vign = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    vign.paste(Image.new("RGB", (N, N), (6, 26, 54)), (0, 0),
               radial_alpha(0.5, 0.52, 1.05, peak=96, power=1.6)
               .point(lambda v: 96 - v))
    img.alpha_composite(Image.composite(
        vign, Image.new("RGBA", (N, N), (0, 0, 0, 0)), mask))

    # Reflet du haut, qui s'eteint vers le milieu.
    g = np.clip(np.linspace(1.0, 0.0, N) ** 2.1 * 54, 0, 255)
    sheen = Image.fromarray(
        np.tile(g.reshape(-1, 1), (1, N)).astype(np.uint8), "L")
    sheen = Image.composite(sheen, Image.new("L", (N, N), 0), mask)
    img.alpha_composite(Image.merge(
        "RGBA", (Image.new("L", (N, N), 255),) * 3 + (sheen,)))

    # Liseré interieur, comme sur les icones systeme : c'est ce detail qui
    # fait « fabrique » plutot que « colorie ».
    ring = Image.new("L", (N, N), 0)
    ImageDraw.Draw(ring).rounded_rectangle(
        [0, 0, N - 1, N - 1], radius=px(0.225), outline=255,
        width=max(1, int(px(0.0055))))
    fade = np.clip(np.linspace(1.0, 0.0, N) ** 1.5 * 150, 0, 255)
    ring = Image.fromarray(
        (np.asarray(ring, np.float64) / 255
         * np.tile(fade.reshape(-1, 1), (1, N))).astype(np.uint8), "L")
    img.alpha_composite(Image.merge(
        "RGBA", (Image.new("L", (N, N), 255),) * 3 + (ring,)))
    return img


def finish(img, name):
    out = img.resize((SIZE, SIZE), Image.LANCZOS)
    out.save(os.path.join(HERE, f"{name}.png"))
    return out


# ------------------------------------------------- A. la boite a histoires

def concept_box():
    """La boite entrouverte, d'ou sort la lumiere.

    C'est le motif de l'ecran d'ouverture : le logo et le lancement racontent
    alors la meme chose. Construite en projection oblique, trois valeurs pour
    trois faces — c'est ce qui fait tenir le volume.
    """
    img = tile()

    body = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    front = [(0.262, 0.584), (0.596, 0.636), (0.596, 0.846), (0.262, 0.794)]
    side = [(0.596, 0.636), (0.754, 0.562), (0.754, 0.772), (0.596, 0.846)]
    rim = [(0.262, 0.584), (0.420, 0.510), (0.754, 0.562), (0.596, 0.636)]
    d.polygon([(px(x), px(y)) for x, y in front], fill=PAPER + (255,))
    d.polygon([(px(x), px(y)) for x, y in side],
              fill=mix(ACCENT, PAPER, 0.74) + (255,))
    d.polygon([(px(x), px(y)) for x, y in rim],
              fill=mix(ACCENT, (0, 0, 0), 0.34) + (255,))

    img.alpha_composite(shadow_of(body, 0, 0.022, 0.030, 150))
    img.alpha_composite(body)

    # La lumiere sort en cone : elle a une direction, pas seulement un halo.
    cone = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(cone).polygon(
        [(px(0.330), px(0.580)), (px(0.690), px(0.600)),
         (px(0.780), px(0.250)), (px(0.250), px(0.235))],
        fill=WARM + (62,))
    img.alpha_composite(cone.filter(ImageFilter.GaussianBlur(px(0.045))))

    halo = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    halo.paste(Image.new("RGB", (N, N), WARM), (0, 0),
               radial_alpha(0.508, 0.572, 0.215, peak=225))
    img.alpha_composite(halo)

    lid = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(lid)
    lid_top = [(0.238, 0.400), (0.396, 0.326), (0.730, 0.378), (0.572, 0.452)]
    lid_front = [(0.238, 0.400), (0.572, 0.452), (0.572, 0.494), (0.238, 0.442)]
    lid_side = [(0.572, 0.452), (0.730, 0.378), (0.730, 0.420), (0.572, 0.494)]

    def turned(poly):
        return rotate_pts([(px(x), px(y)) for x, y in poly],
                          px(0.48), px(0.41), -7)

    d.polygon(turned(lid_top), fill=PAPER + (255,))
    d.polygon(turned(lid_front), fill=mix(ACCENT, PAPER, 0.82) + (255,))
    d.polygon(turned(lid_side), fill=mix(ACCENT, PAPER, 0.62) + (255,))

    img.alpha_composite(shadow_of(lid, 0, 0.030, 0.034, 130))
    img.alpha_composite(lid)

    sp = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(sp)
    star4(d, 0.506, 0.196, 0.072, PAPER + (255,))
    star4(d, 0.668, 0.268, 0.036, PAPER + (215,), rot=12)
    star4(d, 0.348, 0.272, 0.028, PAPER + (180,), rot=-14)
    img.alpha_composite(sp)

    return finish(img, "concept-a-boite")


# ---------------------------------------------------- B. le C calligraphie

def concept_ribbon():
    """Un C trace comme au calame : fin aux extremites, plein dans la courbe.

    Un trait d'epaisseur constante donne une forme de gabarit. En le faisant
    respirer, la lettre redevient un geste — et le monogramme cesse de
    ressembler a une police posee sur un carre.
    """
    img = tile()

    start, end = 38.0, 322.0           # l'ouverture du C, a droite
    ring = 0.268
    hw_max = 0.082                     # demi-epaisseur au plus plein
    steps = 220

    outer, inner = [], []
    for i in range(steps + 1):
        t = i / steps
        ang = math.radians(start + ((end - start) % 360) * t)
        # Fin aux deux bouts, plein au milieu : la plume appuie dans la courbe.
        hw = px(hw_max) * (0.30 + 0.70 * math.sin(math.pi * t) ** 0.62)
        cx = px(0.5) + math.cos(ang) * px(ring)
        cy = px(0.5) + math.sin(ang) * px(ring)
        nx, ny = math.cos(ang), math.sin(ang)
        outer.append((cx + nx * hw, cy + ny * hw))
        inner.append((cx - nx * hw, cy - ny * hw))

    mark = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(mark)
    d.polygon(outer + inner[::-1], fill=(255, 255, 255, 255))
    for ang_deg in (start, end):
        hw = px(hw_max) * 0.30
        a = math.radians(ang_deg)
        cx = px(0.5) + math.cos(a) * px(ring)
        cy = px(0.5) + math.sin(a) * px(ring)
        d.ellipse([cx - hw, cy - hw, cx + hw, cy + hw],
                  fill=(255, 255, 255, 255))

    img.alpha_composite(shadow_of(mark, 0, 0.020, 0.028, 150))
    img.alpha_composite(
        paper_gradient(alpha_mask(mark), PAPER, mix(PAPER, ACCENT, 0.22)))

    # L'etincelle dans le creux, decalee vers l'ouverture : centree, elle
    # bouchait la lettre.
    sp = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    star4(ImageDraw.Draw(sp), 0.536, 0.500, 0.092, PAPER + (255,))
    img.alpha_composite(shadow_of(sp, 0, 0.012, 0.018, 120))
    img.alpha_composite(sp)

    return finish(img, "concept-b-ruban")


# ------------------------------------------------ C. l'etincelle qui ecrit

def concept_spark():
    """Une etincelle dont la trainee devient une ligne d'ecriture.

    L'idee de l'application en une forme : ce qui passe par la tete devient
    une chronique. Silhouette franche, donc lisible tres petit — et surtout
    elle n'appartient qu'a cette application, contrairement a un livre.
    """
    img = tile()

    mark = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(mark)

    def trail_point(t):
        # Plus courte et plus charnue que le premier essai : trop fine, la
        # trainee se lisait comme une flechette et non comme un elan.
        x = 0.326 + (0.742 - 0.326) * t
        y = 0.406 + 0.034 * t ** 1.5
        hw = 0.050 * (1 - t) ** 1.05 + 0.014
        return x, y, hw

    top = [(px(x), px(y - hw))
           for x, y, hw in (trail_point(i / 120) for i in range(121))]
    bottom = [(px(x), px(y + hw))
              for x, y, hw in (trail_point(i / 120) for i in range(120, -1, -1))]
    d.polygon(top + bottom, fill=(255, 255, 255, 255))

    # Les lignes d'ecriture qui suivent la trainee. Trois plutot que deux :
    # elles equilibrent le bas de la tuile, que l'etincelle laissait vide.
    for x0, x1, y in ((0.262, 0.742, 0.556), (0.262, 0.680, 0.646),
                      (0.262, 0.560, 0.736)):
        d.rounded_rectangle([px(x0), px(y), px(x1), px(y + 0.046)],
                            radius=px(0.023), fill=(255, 255, 255, 255))

    img.alpha_composite(shadow_of(mark, 0, 0.020, 0.026, 150))
    img.alpha_composite(
        paper_gradient(alpha_mask(mark), PAPER, mix(PAPER, ACCENT, 0.26)))

    halo = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    halo.paste(Image.new("RGB", (N, N), WARM), (0, 0),
               radial_alpha(0.330, 0.322, 0.240, peak=125))
    img.alpha_composite(halo)

    sp = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    star4(ImageDraw.Draw(sp), 0.330, 0.322, 0.148, PAPER + (255,), waist=0.27)
    img.alpha_composite(shadow_of(sp, 0, 0.014, 0.020, 130))
    img.alpha_composite(sp)

    return finish(img, "concept-c-etincelle")


# ------------------------------------------------------------- comparaison

def _font(size, bold=False):
    names = ("segoeuib.ttf", "arialbd.ttf") if bold else (
        "segoeui.ttf", "arial.ttf", "calibri.ttf")
    for name in names:
        path = os.path.join(os.environ.get("WINDIR", r"C:\Windows"),
                            "Fonts", name)
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def sheet(marks, current=None):
    """Planche de comparaison, avec les apercus en petite taille.

    Un logo se juge a la taille ou on le voit vraiment : dans la barre des
    taches, pas sur une page de presentation.
    """
    pad, gap, big = 58, 52, 290
    items = list(marks) + ([("Actuel", current)] if current else [])
    cols = len(items)
    w = pad * 2 + big * cols + gap * (cols - 1)
    h = pad * 2 + big + 150
    out = Image.new("RGB", (w, h), (245, 248, 251))
    d = ImageDraw.Draw(out)
    title, small = _font(21, bold=True), _font(15)

    for i, (name, mark) in enumerate(items):
        x = pad + i * (big + gap)

        sh = Image.new("RGBA", (big + 80, big + 80), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle(
            [40, 50, big + 40, big + 50], radius=int(big * 0.225),
            fill=(24, 54, 94, 64))
        sh = sh.filter(ImageFilter.GaussianBlur(17))
        out.paste(sh, (x - 40, pad - 40), sh)

        art = mark.resize((big, big), Image.LANCZOS)
        out.paste(art, (x, pad), art if art.mode == "RGBA" else None)

        y = pad + big + 24
        d.text((x, y), name, fill=(24, 44, 70), font=title)

        bx, y2 = x, y + 36
        for s_ in (48, 32, 16):
            th = mark.resize((s_, s_), Image.LANCZOS)
            out.paste(th, (bx, y2 + (48 - s_) // 2),
                      th if th.mode == "RGBA" else None)
            bx += s_ + 14
        d.text((bx + 4, y2 + 15), "48 / 32 / 16 px",
               fill=(128, 146, 168), font=small)

    out.save(os.path.join(HERE, "comparaison.png"))


if __name__ == "__main__":
    a = concept_box()
    b = concept_ribbon()
    c = concept_spark()
    current = Image.open(os.path.join(
        HERE, "..", "..", "assets", "logo.png")).convert("RGB")
    sheet([("A \u2014 la bo\u00eete", a),
           ("B \u2014 le C calligraphi\u00e9", b),
           ("C \u2014 l'\u00e9tincelle qui \u00e9crit", c)], current=current)
    print("pistes generees dans", HERE)
