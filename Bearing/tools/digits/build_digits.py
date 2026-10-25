"""Bearing digits: a thin geometric digit font traced from the design's 1, 0, 4, 7
(SF-style ultralight), the other digits drawn to match. Writes a TTF per stroke weight.
Units: cap height 186 (the design image's px), baseline 0."""
import math, sys
from shapely.geometry import LineString, Polygon, box, Point
from shapely.ops import unary_union
from shapely import affinity
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

CAP = 186.0
N = 2.2           # superellipse exponent of the bowls (fitted to the design's 0)
FLAT = 2          # shapely cap_style flat
MITRE = 2         # join_style mitre

def se_point(cx, cy, a, b, t):
    c, s = math.cos(t), math.sin(t)
    return (cx + a * math.copysign(abs(c) ** (2 / N), c), cy + b * math.copysign(abs(s) ** (2 / N), s))

def arc(cx, cy, a, b, t0, t1, steps=160):
    """Superellipse centre line from angle t0 to t1 (degrees, either direction)."""
    pts = []
    for i in range(steps + 1):
        t = math.radians(t0 + (t1 - t0) * i / steps)
        pts.append(se_point(cx, cy, a, b, t))
    return pts

def ring(cx, cy, a, b, w):
    outer = Polygon(arc(cx, cy, a + w / 2, b + w / 2, 0, 360, 360))
    inner = Polygon(arc(cx, cy, a - w / 2, b - w / 2, 0, 360, 360))
    return outer.difference(inner)

def stroke(pts, w, join=MITRE):
    return LineString(pts).buffer(w / 2, cap_style=FLAT, join_style=join, mitre_limit=8)

def glyphs(w):
    h = w / 2
    g = {}
    # 0: traced; outer 131 x 190 incl. 2 overshoot, centre at 93
    g['0'] = (ring(67, 93, 65.5 - 3.3, 95 - 3.3, w), 134)
    # 1: stem centre 86.5, flag down-left with a vertical cut at 43.5
    stem = box(86.5 - h, 0, 86.5 + h, 185)
    d = (-1.333, -1.0)
    p0 = (74.5 + 1.333 * 12, 175 + 12)
    p1 = (74.5 - 1.333 * 30, 175 - 30)
    flag = stroke([p0, p1], w).intersection(box(43.5, 0, 86.5 + h, 185))
    g['1'] = (unary_union([stem, flag]), 134)
    # 4: stem 97.5, bar at 51 from 1.5 to 131.5, diagonal stem top -> bar's left end
    stem = box(97.5 - h, 0, 97.5 + h, 186)
    bar = box(1.5, 51 - h, 131.5, 51 + h)
    diag = stroke([(97.5 + 0.6964 * 6, 192), (2.3 - 0.6964 * 8, 51 - 8)], w).intersection(box(1.5, 51 - h, 200, 186))
    g['4'] = (unary_union([stem, bar, diag]), 134)
    # 7: top bar 9.5 -> right corner, diagonal to (28.5, 0)
    top = 185.5 - h
    g['7'] = (stroke([(9.5, top), (122.5 - 0.506 * h, top), (28.5 - 0.506 * 4, -4)], w)
              .intersection(box(9.5, 0, 200, 185.5)), 134)
    # 8: small top bowl over a wider bottom bowl
    g['8'] = (unary_union([ring(67, 142, 50, 42.7, w), ring(67, 50, 60.5, 48.7, w)]), 134)
    # 6: closed bottom bowl, the left side rising into the top terminal
    bowl = ring(67, 60, 61, 62 - 2, w)
    # the hook's left side runs straight down into the bowl's (both vertical there)
    hook = LineString(arc(67, 93, 61, 95 - 3.3, 52, 180) + [(6, 60)]).buffer(h, cap_style=1, join_style=1)
    hook = hook.difference(Point(se_point(67, 93, 61, 95 - 3.3, math.radians(52))).buffer(h + 0.01)).union(
        stroke(arc(67, 93, 61, 95 - 3.3, 52, 60), w, 1))
    g['6'] = (unary_union([bowl, hook]), 134)
    # 9: the 6 turned half round
    g['9'] = (affinity.rotate(g['6'][0], 180, origin=(67, 93)), 134)
    # 5: top bar, stem, open bowl
    ba, bb, bcx, bcy = 59, 62 - 3.3, 64, 62 - 3.3 - 2 + 3.3
    start = se_point(bcx, bcy, ba, bb, math.radians(152))
    bowl = arc(bcx, bcy, ba, bb, 152, -148)
    five = unary_union([
        stroke([(116, 185.5 - h), (22, 185.5 - h), start], w),
        stroke(bowl, w, join=1),
    ])
    g['5'] = (five.intersection(box(-50, -2, 300, 185.5)), 134)
    # 3: top bowl, short middle bar, bottom bowl
    tb = arc(63, 142.5, 49, 44.5 - 1.0, 152, -90)
    bt = arc(66, 48, 60, 50, 90, -150)
    three = unary_union([stroke(tb, w, 1), stroke([(63, 98), (40, 98)], w), stroke([(40, 98), (66, 98)], w),
                         stroke(bt, w, 1)])
    g['3'] = (three, 134)
    # 2: bowl arc, diagonal to the bottom left, base bar
    end = se_point(65, 131, 54, 54, math.radians(-38))
    two = unary_union([stroke(arc(65, 131, 54, 54, 160, -38), w, 1),
                       stroke([end, (12, h)], w),
                       box(9, 0, 125, w)])
    two = two.intersection(box(9, 0, 300, 300))
    g['2'] = (two, 134)
    return g

def extras(w):
    """Small-text glyphs: % , - (Light font only)."""
    g = {}
    h = w / 2
    pct = unary_union([ring(40, 140, 30, 40, w), ring(134, 46, 30, 40, w),
                       stroke([(150, 186), (24, 0)], w)])
    g['%'] = (affinity.translate(pct, 4, 0), 182)
    # the design's comma: 28 units wide, from 28 above to 28 below the baseline
    g[','] = (stroke([(34, 22), (20, -28 + w * 0.6)], w * 1.3).union(Point(31.5, 17).buffer(w * 0.85))
              .intersection(box(0, -28, 100, 30)), 58)
    g['-'] = (box(14, 82 - h, 74, 82 + h), 88)
    g[' '] = (None, 60)
    return g

def to_ttf(name, style, w, out, with_extras):
    g = glyphs(w)
    if with_extras:
        # small text: the design's digit pitch is 0.85 of the cap height (8,560), not 0.72
        g = {c: (affinity.translate(sh, 12, 0), 158) for c, (sh, adv) in g.items()}
        g.update(extras(w))
    k = 700.0 / CAP
    order = ['.notdef'] + ['uni%04X' % ord(c) if c != ' ' else 'space' for c in g]
    cmap = {}
    glyf = {'.notdef': TTGlyphPen(None).glyph()}
    metrics = {'.notdef': (600, 0)}
    for c, (shape, adv) in g.items():
        gn = 'uni%04X' % ord(c) if c != ' ' else 'space'
        cmap[ord(c)] = gn
        pen = TTGlyphPen(None)
        if shape is not None:
            polys = list(shape.geoms) if hasattr(shape, 'geoms') else [shape]
            for p in polys:
                p = p.simplify(0.08)
                rings = [(p.exterior, True)] + [(r, False) for r in p.interiors]
                for r, outer in rings:
                    pts = [(round(x * k), round(y * k)) for x, y in list(r.coords)[:-1]]
                    # TrueType: outer contours clockwise, holes counter-clockwise
                    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
                    cw = area < 0
                    if cw != outer:
                        pts.reverse()
                    dedup = [pts[0]] + [q for i, q in enumerate(pts[1:], 1) if q != pts[i - 1]]
                    if len(dedup) < 3:
                        continue
                    pen.moveTo(dedup[0])
                    for q in dedup[1:]:
                        pen.lineTo(q)
                    pen.closePath()
        glyf[gn] = pen.glyph()
        metrics[gn] = (round(adv * k), 0)
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyf)
    for gn in order:
        gl = glyf[gn]
        gl.recalcBounds(fb.font['glyf'])
        lsb = gl.xMin if hasattr(gl, 'xMin') and gl.numberOfContours else 0
        metrics[gn] = (metrics[gn][0], lsb)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fam = 'Bearing ' + name
    fb.setupNameTable({'familyName': fam, 'styleName': 'Regular', 'uniqueFontIdentifier': fam.replace(' ', '') + '-Regular',
                       'fullName': fam, 'psName': fam.replace(' ', '') + '-Regular', 'version': 'Version 1.000',
                       'copyright': 'Bearing watch face, drawn for this repository'})
    fb.setupOS2(sTypoAscender=800, sTypoDescender=-200, sTypoLineGap=0, usWinAscent=800, usWinDescent=200,
                sCapHeight=700, sxHeight=500, achVendID='NONE', fsType=0, usWeightClass=100 if w < 10 else 300)
    fb.setupPost()
    fb.setupHead(unitsPerEm=1000)
    fb.save(out)

if __name__ == '__main__':
    outdir = sys.argv[1]
    to_ttf('Thin', 'Regular', 6.6, f'{outdir}/BearingDigits-Thin.ttf', False)
    to_ttf('Light', 'Regular', 13.0, f'{outdir}/BearingDigits-Light.ttf', True)
