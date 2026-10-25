"""Propuestas de logo para UltraScanner con VectorCraft (comandos headless).

Misma familia visual que UltraVocal (propuesta B): fondo ciruela, trazo grueso redondeado con
degradado naranja → rosa y brillo, punto rosa como remate y elementos blancos translúcidos.

    python Design/scripts/logo_ultrascanner.py Design/logo-propuestas
"""
import json
import subprocess
import sys
from pathlib import Path

CLI = r"C:\Program Files\VectorCraft\vectorcraft-cli.exe"
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")

# Paleta de UltraVocal.
BG = ("#2a0f35", "#5a1542", -60)
TRACE = ("#ffb347", "#ff4f8b")
TRACE_GLOW = ("#ff7a59", 26, 55)
DOT = ("#ff8aa8", "#ff4f8b")
DOT_GLOW = ("#ff4f8b", 30, 60)


class Canvas:
    """Lienzo de 1024 x 1024 con desplazamiento y escala (mismo esquema que el de UltraVocal)."""

    def __init__(self, ox=0.0, oy=0.0, s=1.0):
        self.ox, self.oy, self.s = ox, oy, s
        self.cmds = []

    def p(self, x, y):
        return (self.ox + x * self.s, self.oy + y * self.s)

    def cmd(self, cid, params=None):
        self.cmds.append((cid, params or {}))

    def d(self, parts):
        out = []
        for op, *nums in parts:
            pts = [self.p(nums[i], nums[i + 1]) for i in range(0, len(nums), 2)]
            out.append(op + " " + " ".join(f"{x:.2f} {y:.2f}" for x, y in pts))
        return " ".join(out)

    @staticmethod
    def grad(c0, c1, angle=0):
        return {"gradient": {"kind": "linear", "angle": angle,
                             "stops": [{"offset": 0, "color": c0}, {"offset": 1, "color": c1}]}}

    def paint(self, fill=None, stroke=None, weight=None, opacity=None, glow=None):
        self.cmd("paint.setFill", fill if fill else {"none": True})
        self.cmd("paint.setStroke", stroke if stroke else {"none": True})
        if stroke:
            self.cmd("stroke.set", {"weight": weight * self.s, "cap": "round", "join": "round"})
        if opacity is not None:
            self.cmd("object.setProps", {"opacity": opacity})
        if glow:
            color, blur, op = glow
            self.cmd("effect.apply", {"effect": "stylize.outerGlow",
                                      "params": {"color": color, "blur": blur * self.s, "opacity": op, "mode": "screen"}})

    def path(self, parts, **paint):
        self.cmd("path.create", {"d": self.d(parts)})
        self.paint(**paint)

    def rect(self, x, y, w, h, r=0, **paint):
        x0, y0 = self.p(x, y)
        self.cmd("shape.rectangle", {"x": x0, "y": y0, "width": w * self.s, "height": h * self.s, "radius": r * self.s})
        self.paint(**paint)

    def circle(self, cx, cy, r, **paint):
        x0, y0 = self.p(cx - r, cy - r)
        self.cmd("shape.ellipse", {"x": x0, "y": y0, "width": 2 * r * self.s, "height": 2 * r * self.s})
        self.paint(**paint)

    def background(self, rounded):
        # Ícono: cuadrado completo (iOS recorta las esquinas). Hoja: con la esquina de iOS.
        c0, c1, angle = BG
        self.rect(0, 0, 1024, 1024, r=229 if rounded else 0, fill=self.grad(c0, c1, angle))


def corners(x0, y0, x1, y1, arm, radius):
    """Las cuatro esquinas de un visor de cámara, cada una como un trazo en L redondeado."""
    k = radius * 0.45  # control de la curva (aprox. cuarto de círculo)
    return [
        [("M", x0, y0 + arm), ("L", x0, y0 + radius), ("C", x0, y0 + k, x0 + k, y0, x0 + radius, y0), ("L", x0 + arm, y0)],
        [("M", x1 - arm, y0), ("L", x1 - radius, y0), ("C", x1 - k, y0, x1, y0 + k, x1, y0 + radius), ("L", x1, y0 + arm)],
        [("M", x1, y1 - arm), ("L", x1, y1 - radius), ("C", x1, y1 - k, x1 - k, y1, x1 - radius, y1), ("L", x1 - arm, y1)],
        [("M", x0 + arm, y1), ("L", x0 + radius, y1), ("C", x0 + k, y1, x0, y1 - k, x0, y1 - radius), ("L", x0, y1 - arm)],
    ]


def draw_corners(c, x0, y0, x1, y1, arm=150, radius=70, weight=46):
    for parts in corners(x0, y0, x1, y1, arm, radius):
        c.path(parts, stroke=c.grad(*TRACE, -45), weight=weight, glow=TRACE_GLOW)


# --- Propuestas -------------------------------------------------------------------------------

def a_viewfinder_scan(c, rounded):
    """A · Visor y línea de escaneo: esquinas de cámara, renglones del documento y el haz que
    lo recorre rematado en el punto rosa (como la voz que sube en UltraVocal)."""
    c.background(rounded)
    for y, w in ((372, 360), (444, 300), (596, 340), (668, 250)):
        c.rect(332, y - 22, w, 44, r=22, fill={"color": "#ffffff"}, opacity=20)
    draw_corners(c, 222, 222, 802, 802)
    c.path([("M", 300, 520), ("L", 690, 520)], stroke=c.grad(*TRACE, 0), weight=40, glow=TRACE_GLOW)
    c.circle(724, 520, 40, fill=c.grad(*DOT, -90), glow=DOT_GLOW)


def b_page_trace(c, rounded):
    """B · Página: una hoja con la esquina doblada dibujada con el trazo de UltraVocal y el punto
    marcando dónde va el escaneo."""
    c.background(rounded)
    page = [("M", 378, 240), ("L", 590, 240), ("L", 720, 370), ("L", 720, 740),
            ("C", 720, 766, 699, 784, 672, 784), ("L", 378, 784),
            ("C", 351, 784, 330, 766, 330, 740), ("L", 330, 288), ("C", 330, 261, 351, 240, 378, 240)]
    c.path(page, stroke=c.grad(*TRACE, -60), weight=44, glow=TRACE_GLOW)
    c.path([("M", 590, 240), ("L", 590, 330), ("C", 590, 352, 605, 370, 630, 370), ("L", 720, 370)],
           stroke=c.grad(*TRACE, -60), weight=36, glow=TRACE_GLOW)
    for y, w in ((470, 250), (550, 290), (630, 210)):
        c.rect(400, y - 20, w, 40, r=20, fill={"color": "#ffffff"}, opacity=22)
    c.circle(720, 784, 40, fill=c.grad(*DOT, -90), glow=DOT_GLOW)


def c_focus(c, rounded):
    """C · Enfoque: solo el visor y el punto al centro. La más simple; se lee bien en pequeño."""
    c.background(rounded)
    draw_corners(c, 232, 232, 792, 792, arm=170, radius=80, weight=52)
    c.circle(512, 512, 62, fill=c.grad(*DOT, -90), glow=DOT_GLOW)


DESIGNS = [
    ("A", "Visor y escaneo", a_viewfinder_scan),
    ("B", "Página", b_page_trace),
    ("C", "Enfoque", c_focus),
]


def run(cmds, export, size):
    args = [CLI, "run", "--cmd", "file.new", "--params", json.dumps({"width": size[0], "height": size[1], "units": "Pixels"})]
    for cid, params in cmds:
        args += ["--cmd", cid, "--params", json.dumps(params, ensure_ascii=False)]
    for path in export:
        args += ["--export", str(path)]
    result = subprocess.run(args, capture_output=True, text=True, encoding="utf-8")
    failures = [line for line in result.stdout.splitlines() if '"error"' in line]
    if result.returncode != 0 or failures:
        print(result.stdout[-2000:], result.stderr[-2000:])
        raise SystemExit(f"falló {export}")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for key, name, draw in DESIGNS:
        c = Canvas()
        draw(c, rounded=False)
        run(c.cmds, [OUT / f"logo-{key}.png", OUT / f"logo-{key}.svg"], (1024, 1024))
        print("ok", key, name)

    # Hoja comparativa: el logo de UltraVocal de referencia + las 3 propuestas, con la esquina de
    # iOS y en tamaño grande y pequeño (como se ve en la pantalla de inicio).
    icon, cell_w, top = 300, 380, 120
    sheet = Canvas()
    sheet.rect(0, 0, 1240, 590, fill={"color": "#eef0f4"})
    sheet.cmd("text.create", {"x": 50, "y": 70, "text": "UltraScanner · propuestas de logo (paleta UltraVocal)",
                              "size": 34, "font": "Segoe UI", "style": "Semibold", "color": "#1a1c22"})
    for i, (key, name, draw) in enumerate(DESIGNS):
        ox = 60 + i * cell_w + (cell_w - icon) / 2
        c = Canvas(ox, top, icon / 1024)
        draw(c, rounded=True)
        sheet.cmds += c.cmds
        small = Canvas(ox, top + icon + 40, 72 / 1024)
        draw(small, rounded=True)
        sheet.cmds += small.cmds
        sheet.cmd("text.create", {"x": ox + 92, "y": top + icon + 86, "text": f"{key} · {name}",
                                  "size": 24, "font": "Segoe UI", "style": "Semibold", "color": "#1a1c22"})
    run(sheet.cmds, [OUT / "propuestas.png"], (1240, 590))
    print("ok hoja")


if __name__ == "__main__":
    main()
