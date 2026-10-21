# Swiss Glyphs — 16x16 grid, y down, solid geometry, 2px minimum feature (= marker), 1px only for "inactive" outlines (= rule)
from shapely.geometry import Polygon, LineString, box
from shapely.ops import unary_union
def R(x0,y0,x1,y1): return box(x0,y0,x1,y1)
def P(*pts): return Polygon(pts)
def O(x0,y0,x1,y1,t=2): return box(x0,y0,x1,y1).difference(box(x0+t,y0+t,x1-t,y1-t))
def L(*pts,w=2): return LineString(pts).buffer(w/2,cap_style=2,join_style=2,mitre_limit=4)
def U(*g): return unary_union(g)
def slash(g):  # struck-through: cut a 4px channel, lay a 2px bar
    return U(g.difference(L((0,0),(16,16),w=4.8)).intersection(R(0,0,16,16)), L((1,1),(15,15)).intersection(R(0,0,16,16)))
SPK=P((1,5),(4,5),(8,1),(8,15),(4,11),(1,11))
def bars(n, total=4):  # signal bands: active solid, inactive 1px outline
    out=[]; hs=[4,7,10,13]
    for i in range(total):
        x=1+i*4; y=15-hs[i]
        out.append(R(x,y,x+2,15) if i<n else O(x,y,x+3,15,1) if False else box(x,y,x+2,15).difference(box(x+1,y+1,x+1,14)) if False else O(x,y,x+2,15,1) if False else None)
    return out
def wifi(n):
    g=[]; hs=[4,7,10,13]
    for i in range(4):
        x=1+i*4; y=15-hs[i]
        g.append(R(x,y,x+3,15) if i<n else O(x,y,x+3,15,1))
    return U(*g)
MIC=U(R(6,1,10,9), R(3,6,5,12), R(11,6,13,12), R(3,10,13,12), R(7,12,9,14), R(4,14,12,16))
LAN=U(R(6,1,10,5), R(1,11,5,15), R(11,11,15,15), R(7,5,9,8), R(2,7,14,9), R(2,9,4,11), R(12,9,14,11))
BT=L((4,4.5),(12,11),(8,14.5),(8,1.5),(12,5),(4,11.5))
BELL=U(P((4,3),(12,3),(12,11),(15,12),(15,14),(1,14),(1,12),(4,11)), R(6,14,10,16), R(7,1,9,3))
G={
 'volume-mute':  U(SPK, L((10,5),(15,10)), L((10,10),(15,5))),
 'volume-0':     SPK,
 'volume-1':     U(SPK, R(10,6,12,10)),
 'volume-2':     U(SPK, R(10,6,12,10), R(13,3,15,13)),
 'mic':          MIC,
 'mic-off':      slash(MIC),
 'wifi-0':       wifi(0), 'wifi-1': wifi(1), 'wifi-2': wifi(2), 'wifi-3': wifi(3), 'wifi-4': wifi(4),
 'wifi-off':     slash(wifi(0)),
 'lan':          LAN,
 'lan-off':      slash(LAN),
 'bluetooth':    BT,
 'bluetooth-connected': U(BT, R(0,7,2,9), R(14,7,16,9)),
 'bluetooth-off': slash(BT),
 'bell':         BELL,
 'bell-off':     slash(BELL),
 'theme':        U(O(1,1,15,15), R(8,1,15,15)),
 'play':         P((4,2),(13,8),(4,14)),
 'pause':        U(R(3,2,6,14), R(10,2,13,14)),
 'next':         U(P((2,2),(10,8),(2,14)), R(11,2,14,14)),
 'prev':         U(P((14,2),(6,8),(14,14)), R(2,2,5,14)),
 'close':        U(L((3,3),(13,13)), L((13,3),(3,13))),
 'check':        L((2,8),(6,12),(14,4)),
 'error':        R(1,1,15,15).difference(U(R(7,3,9,10), R(7,11,9,13))),
 'warning':      P((8,1),(15,15),(1,15)).difference(U(R(7,6,9,11), R(7,12,9,14))),
 'chevron-left': L((10,2),(4,8),(10,14)),
 'chevron-right':L((6,2),(12,8),(6,14)),
 'chevron-up':   L((2,10),(8,4),(14,10)),
 'chevron-down': L((2,6),(8,12),(14,6)),
 'lock':         U(R(2,7,14,15), O(4,1,12,9)).difference(R(7,10,9,13)),
 'calendar':     U(O(1,3,15,15), R(1,3,15,7), R(4,1,6,4), R(10,1,12,4)),
 'more':         U(R(1,7,3,9), R(7,7,9,9), R(13,7,15,9)),
 'search':       U(O(1,1,11,11), L((10,10),(15,15))),
 'headphones':   U(O(1,1,15,10).difference(R(3,8,13,10)).difference(R(1,9,15,10)) , R(1,8,5,15), R(11,8,15,15)),
 'display':      U(O(1,1,15,11), R(7,11,9,14), R(4,13,12,15)),
 'music':        U(R(10,1,12,13), R(10,1,15,4), R(5,9,12,15)),
 'plus':         U(R(7,2,9,14), R(2,7,14,9)),
 'minus':        R(2,7,14,9),
}
NAMES=list(G)
# --- appended v1.1 (codepoints continue; never reorder) ---
CUP_BODY=P((2,6),(12,6),(11,15),(3,15))
G['awake']     = U(CUP_BODY, O(11,7,15,12), R(4,1,6,4), R(8,1,10,4))
G['awake-off'] = U(CUP_BODY.difference(P((4,8),(10,8),(9.25,13),(4.75,13))), O(11,7,15,12))
G['agent']     = U(O(1,1,15,15), L((4,5),(7,8),(4,11)), R(8,10,12,12))
NAMES=list(G)
# --- NixOS snowflake, geometry from NixOS/nixos-artwork logo/nix-snowflake-colours.svg (CC-BY 4.0), fitted to the 16px grid ---
def _nix():
    from shapely import affinity
    d=[(309.54892,-710.38827),(122.19683,211.67512),(-56.15706,0.5268),(-32.6236,-56.8692),(-32.85645,56.5653),(-27.90237,-0.011),(-14.29086,-24.6896),(46.81047,-80.4901),(-33.22946,-57.8257)]
    pts=[d[0]]
    for dx,dy in d[1:]: pts.append((pts[-1][0]+dx,pts[-1][1]+dy))
    lam=Polygon(pts)
    rot=lambda a,cx,cy: affinity.rotate(lam,a,origin=(cx,cy))
    A=[rot(60,407.11155,-715.78724), rot(-60,407.31177,-715.70016), rot(180,407.41868,-715.7565)]
    B=[lam, rot(120,407.33916,-716.08356), rot(-120,407.28823,-715.86995)]
    allg=unary_union(A+B); x0,y0,x1,y1=allg.bounds; s=15/max(x1-x0,y1-y0)
    fit=lambda g: affinity.translate(affinity.scale(g,s,s,origin=(x0,y0)), 0.5-x0+(15-(x1-x0)*s)/2, 0.5-y0+(15-(y1-y0)*s)/2)
    return fit(unary_union(B)), fit(unary_union(A)), fit(allg)
_b,_a,_all=_nix()
G['nixos']=_all; G['nixos-a']=_b; G['nixos-b']=_a   # nixos = whole mark; -a / -b = alternating lambda sets for two-tone
NAMES=list(G)
# --- appended v1.2 for NixDesk (codepoints continue; never reorder) ---
# power: the power menu's mark: the IEC symbol, a 2px ring with a bar through its gap (a square ring read as "upload"
# at 16px; the circle is what makes it power). Since the panels package (v1.3 there, U+E030) the gap is its wedge from
# the centre, so the ring's ends are radial; the codepoint stays U+E02F here.
from shapely.geometry import Point
_ring = Point(8,9).buffer(6.5, quad_segs=32).difference(Point(8,9).buffer(4.5, quad_segs=32))
G['power']       = U(_ring.difference(P((8,9),(3,-2),(13,-2))), R(7,1,9,9))
# square / square-off: an on/off state mark (keep awake): filled when on, a 1px outline when off (the set's rule for
# inactive parts); 10px, centred, so it sits with the line glyphs without outweighing them
G['square']      = R(3,3,13,13)
G['square-off']  = O(3,3,13,13,1)
# bell-unread: the bell with a 4px square at its shoulder, clear of it by 2px: unread told by shape, not colour
G['bell-unread'] = U(BELL.difference(R(10,0,16,6)), R(12,0,16,4))
NAMES=list(G)
# --- appended v1.3 for NixDesk (codepoints continue; never reorder) ---
# tick: keep awake as the bar draws it, a 2px stroke standing on the baseline (the tags' language); the tile's glyph
G['tick']        = R(7,2,9,15)
NAMES=list(G)
# --- appended v1.4 for NixDesk (codepoints continue; never reorder) ---
# small chevrons: the tray drawer's toggle, a quiet mark (the owner asked for "a very small chevron"); 2px stroke,
# 6px tall, centred in the 16px box
G['chevron-left-small']  = L((10,5),(7,8),(10,11))     # ink centred in the box (it sat 1 px left)
G['chevron-right-small'] = L((6,5),(9,8),(6,11))      # ink centred in the box
NAMES=list(G)
# --- appended v1.5 from the design-systems package (codepoints continue; never reorder) ---
# night: the dashboard's night light, a crescent. The package numbers it U+E02F, which is power here; the package's
# preview fonts (design/*/fonts) keep its numbering, the shell's font gives it the next free codepoint
from shapely.geometry import Point as _Pt
G['night'] = _Pt(8,8.5).buffer(6.5, quad_segs=32).difference(_Pt(11.5,5).buffer(5.5, quad_segs=32))
NAMES=list(G)
# --- appended v1.6 from the display package (codepoints continue; never reorder) ---
# brightness: the Display panel's and the bar's sun, an 8px ring (2px stroke) with eight pixel-aligned rays: 2x2 bars on
# the axes, 2x2 squares on the diagonals. The package numbers it U+E031 (square-off here): in the shell it is U+E037.
G['brightness'] = U(_Pt(8,8).buffer(4, quad_segs=32).difference(_Pt(8,8).buffer(2, quad_segs=32)),
                    R(7,0,9,2), R(7,14,9,16), R(0,7,2,9), R(14,7,16,9),
                    R(2,2,4,4), R(12,2,14,4), R(2,12,4,14), R(12,12,14,14))
NAMES=list(G)
# --- appended v1.7 from the tray-row package (codepoints continue; never reorder) ---
# stay-awake: keep awake in the bar and its tiles, an open eye while the screen is kept awake, a closed eye with lashes
# while it may sleep (it replaced the tick, which read as a comma). Almond = two circles' intersection, 2px outline.
# The package numbers them U+E032 / U+E033 (bell-unread and tick here): in the shell they are U+E038 / U+E039.
def _almond(top,bot,half=7):
    s=(bot-top)/2; r=(half*half+s*s)/(2*s)
    return _Pt(8,top+r).buffer(r,quad_segs=64).intersection(_Pt(8,bot-r).buffer(r,quad_segs=64))
_eye=_almond(3,13); _eyeO=_eye.difference(_almond(5,11,5.2))
G['stay-awake']     = U(_eyeO, _Pt(8,8).buffer(1.75,quad_segs=32))
from shapely.affinity import translate as _tr
G['stay-awake-off'] = _tr(U(_eyeO.intersection(R(0,8,16,16)), R(7,12,9,15), L((4.2,11.2),(3,13.6)), L((11.8,11.2),(13,13.6))), 0, -2)  # centred: 6-13
NAMES=list(G)
# --- appended v1.8 for NixDesk (codepoints continue; never reorder) ---
# sleep / sleep-off: keep awake in the bar and the dashboard, the owner's pick after the eyes. "Zz" while the screen may
# sleep; struck through (the set's slash, as bell-off) while it is kept awake. A big Z low left (8px wide, 2px bars,
# a 2px-wide diagonal) and a small z stepped up right, a pixel clear of it.
def _z(x0,y0,x1,y1):
    return U(R(x0,y0,x1,y0+2), P((x1-2,y0+2),(x1,y0+2),(x0+2,y1-2),(x0,y1-2)), R(x0,y1-2,x1,y1))
_zz = U(_z(1,8,9,16), _z(10,1,15,7))
G['sleep']     = _zz
G['sleep-off'] = slash(_zz)
NAMES=list(G)

# --- Swiss Glyphs 1.6 from the package (swiss-glyphs-1.6.zip), its block verbatim: redrawings only, at the shell's own
# codepoints (the package numbers its 52 glyphs U+E000-E033; this font keeps its local ones and their numbers). It
# replaces the lighter square theme drawn here in v1.8 with the package's half-filled circle.
# --- v1.6 weight pass: shapes redrawn at the same codepoints so every status glyph carries ~75-105 px2 of ink ---
from shapely.geometry import Point as _P2
_C=lambda x,y,r: _P2(x,y).buffer(r,quad_segs=48)
# theme: a contrast circle (ring + left half filled) instead of a half-filled box (146 -> ~100 px2; no longer reads as "sidebar")
G['theme'] = U(_C(8,8,6.5).difference(_C(8,8,4.5)), _C(8,8,4.5).intersection(R(0,0,8,16)))
# bell: slimmer body, same silhouette (115 -> ~95 px2)
BELL2=U(P((5,3.5),(11,3.5),(11.5,11),(14,12.5),(14,14),(2,14),(2,12.5),(4.5,11)), R(6.5,14,9.5,16), R(7,1.5,9,3.5))
G['bell'] = BELL2
G['bell-off'] = slash(BELL2)
# brightness: solid sun — a 7px disc with the same eight pixel rays (70 -> ~80 px2, matches the solid set)
G['brightness'] = U(_C(8,8,3.5), R(7,0,9,3), R(7,13,9,16), R(0,7,3,9), R(13,7,16,9), R(2,2,4,4), R(12,2,14,4), R(2,12,4,14), R(12,12,14,14))
# bluetooth: clipped to the 16px box (its mitred corners overshot to 17px)
G['bluetooth'] = BT.intersection(R(0,0,16,16))
G['bluetooth-connected'] = U(G['bluetooth'], R(0,7,2,9), R(14,7,16,9))
G['bluetooth-off'] = slash(G['bluetooth'])
# chevron: taller and 1px wider stroke reach (34 -> ~42 px2); stays the lightest on purpose — it's a control, not a state
G['chevron-left']  = L((11,1),(4,8),(11,15))
G['chevron-right'] = L((5,1),(12,8),(5,15))
# stay-awake: pupil 2px radius (68 -> ~72)
G['stay-awake'] = U(_eyeO, _C(8,8,2))
NAMES=list(G)

# --- v1.6 Wi-Fi: a fan of arcs instead of bars (bars read as mobile signal). Same codepoints wifi-0..4 / wifi-off.
# Apex at (8,14.5), 76 degree opening; dot + three 2px bands, 1.5px gaps. Active band = solid 2px; inactive = 1px hairline arc.
import math as _m
def _sector(r0,r1,half=37,cx=8,cy=14.5,n=48):
    a0,a1=_m.radians(-90-half),_m.radians(-90+half)
    outer=[(cx+r1*_m.cos(a0+(a1-a0)*i/n), cy+r1*_m.sin(a0+(a1-a0)*i/n)) for i in range(n+1)]
    inner=[(cx+r0*_m.cos(a1-(a1-a0)*i/n), cy+r0*_m.sin(a1-(a1-a0)*i/n)) for i in range(n+1)] if r0>0 else [(cx,cy)]
    return Polygon(outer+inner)
_BANDS=[(0,2.8),(4.2,6.2),(7.6,9.6),(11,13)]
def _hair(r0,r1): m=(r0+r1)/2; return _sector(m-0.5,m+0.5)
def wifi2(n):
    parts=[]
    for i,(r0,r1) in enumerate(_BANDS):
        parts.append(_sector(r0,r1) if i<n else (_sector(0,1.5) if i==0 else _hair(r0,r1)))
    return U(*parts).intersection(R(0,0,16,16))
for k in range(5): G['wifi-%d'%k]=wifi2(k)
G['wifi-off']=slash(wifi2(0))
NAMES=list(G)

# --- v1.6 search: a round lens (2px ring) and a 2px handle at 45 degrees, instead of a square lens
G['search'] = U(_C(6.5,6.5,5.5).difference(_C(6.5,6.5,3.5)), L((10.4,10.4),(15,15)))
NAMES=list(G)

# bell-unread (local, v1.2) follows the slimmer bell: the same 4px square at the shoulder, 2px clear of it.
G['bell-unread'] = U(BELL2.difference(R(10,0,16,6)), R(12,0,16,4))
NAMES=list(G)

# --- v1.9 for NixDesk: optical centring, measured on the live bar (shifts by whole pixels, so edges stay crisp) ---
# chevrons: their ink sat 0.85 px off the box centre (left one left, right one right), widening the gap to the next slot
G['chevron-left']  = _tr(G['chevron-left'], 1, 0)
G['chevron-right'] = _tr(G['chevron-right'], -1, 0)
# awake-off: the hollow cup kept the steam's room above it and sat 2.5 px low (centre y 10.5); now 8.5, as bell and power
G['awake-off']     = _tr(G['awake-off'], 0, -2)
NAMES=list(G)

# --- v2.0 for NixDesk: the balance pass (the owner: "visual balance and swiss is important", 15 October 2026) ---
# Every status glyph inside the same 14 px live area (1..15, 1 px clear of the 16 px box), centred, 2 px strokes, so
# the bar row reads at one size and one weight. Measured on the live bar before: the sun, Bluetooth and Claude filled
# the whole 16 px box, the Wi-Fi fan ran edge to edge, the bell and power sat low, the speaker was the heaviest.
_C2=lambda x,y,r: _P2(x,y).buffer(r,quad_segs=48)
# Bluetooth: the rune 11 px tall instead of 13, its mitred tips cut flat at the live area (they reached 0.3 and 15.7)
_BT2=L((4.5,5),(11.5,10.5),(8,13.5),(8,2.5),(11.5,5.5),(4.5,11)).intersection(R(0,1,16,15))
G['bluetooth'] = _BT2
G['bluetooth-connected'] = U(_BT2, R(0,7,2,9), R(14,7,16,9))
G['bluetooth-off'] = slash(_BT2)
# sun: a 6 px disc, rays inside 1..15 (they touched the box's edges)
G['brightness'] = U(_C2(8,8,3), R(7,1,9,3), R(7,13,9,15), R(1,7,3,9), R(13,7,15,9), R(3,3,5,5), R(11,3,13,5), R(3,11,5,13), R(11,11,13,13))
# Wi-Fi: the same fan opened 33 degrees each side instead of 37, so it is 14 px wide, not 15.6
def _wifi3(n, half=33):
    parts=[]
    for i,(r0,r1) in enumerate(_BANDS):
        if i<n: parts.append(_sector(r0,r1,half=half))
        elif i==0: parts.append(_sector(0,1.5,half=half))
        else: m=(r0+r1)/2; parts.append(_sector(m-0.5,m+0.5,half=half))
    return U(*parts).intersection(R(0,0,16,16))
for k in range(5): G['wifi-%d'%k]=_wifi3(k)
G['wifi-off']=slash(_wifi3(0))
# speaker: 12 px tall (2..14), the second wave 8 px: the lightest it can be and still read as the set's speaker
_SPK2=P((1,6),(4,6),(8,2),(8,14),(4,10),(1,10))
G['volume-0'] = _SPK2
G['volume-1'] = U(_SPK2, R(10,6,12,10))
G['volume-2'] = U(_SPK2, R(10,6,12,10), R(13,4,15,12))
G['volume-mute'] = U(_SPK2, L((10,6),(14,10)), L((10,10),(14,6)))
# bell: lifted to 1..15 (it hung to 16), 10 px wide at the rim instead of 12 (it was the second heaviest glyph)
_BELL3=U(P((5.5,3),(10.5,3),(11,10),(13,11.5),(13,13),(3,13),(3,11.5),(5,10)), R(6.5,13,9.5,15), R(7,1,9,3))
G['bell'] = _BELL3
G['bell-off'] = slash(_BELL3)
G['bell-unread'] = U(_BELL3.difference(R(10,0,16,6)), R(12,0,16,4))
# power: the ring centred at y 8.5 (it reached 15.5), the bar from the top edge of the live area
G['power'] = U(_C2(8,8.5,6.5).difference(_C2(8,8.5,4.5)).difference(P((8,8.5),(3,-1.5),(13,-1.5))), R(7,1,9,8.5))
# chevrons: 12 px tall, centred (they ran 0.3..15.7)
G['chevron-left']  = _tr(L((10.5,2),(4.5,8),(10.5,14)), 1, 0)     # ink centred: x 4.1..12.2
G['chevron-right'] = _tr(L((5.5,2),(11.5,8),(5.5,14)), -1, 0)    # ink centred: x 3.8..11.9
# theme: the same half-filled circle at 12 px (2..14): at 13 px it carried the most ink of any glyph in the bar
G['theme'] = U(_C2(8,8,6).difference(_C2(8,8,4)), _C2(8,8,4).intersection(R(0,0,8,16)))
NAMES=list(G)
# --- appended v2.0 (codepoints continue; never reorder) ---
# awake-dot / awake-dot-off: keep awake as the shell's own on/off mark, the owner's pick: a filled 10 px circle while
# the screen is kept awake, a 2 px ring while it may sleep
G['awake-dot']     = _C2(8,8,5)
G['awake-dot-off'] = _C2(8,8,5).difference(_C2(8,8,3))
NAMES=list(G)

# bell (v2.1, local, 15 October 2026 evening): the owner found the bell "bad": its narrow flat top on a straight body read
# as a pawn or a bottle. Picked from rendered options (fixes-rig/bell-review.png): a solid bell with a round dome (r 4,
# x 4..12), a slightly flared body, an 11 px rim, the hanging loop and a half-round clapper 1 px clear below the rim.
# Unread and do not disturb keep their marks (the square at the shoulder, the slash).
from shapely.geometry import Point as _Pb
_BELL4 = U(_Pb(8, 7).buffer(4, 64).intersection(R(0, 0, 16, 7)), P((4, 7), (12, 7), (12.6, 10.5), (3.4, 10.5)),
           R(2.5, 10.5, 13.5, 12.5), R(7, 1.5, 9, 3.2), _Pb(8, 13.5).buffer(1.5, 64).intersection(R(0, 13.5, 16, 16)))
G['bell'] = _BELL4
G['bell-off'] = slash(_BELL4)
G['bell-unread'] = U(_BELL4.difference(R(10, 0, 16, 6)), R(12, 0, 16, 4))
NAMES = list(G)

# nixos-rest / nixos-accent (v2.2, local, 15 October 2026 evening): the Swiss two-tone NixOS mark from the owner's
# nixos-two-tone-bar package (Swiss Glyphs 1.7): five arms in ink, one (top left) in the accent, stacked in one box
# (components/NixMark). Ported as data (nixos-two-tone.json: the package's SVG rings, even-odd) at new codepoints after
# this font's own glyphs; the package's font was not swapped in, because its numbering differs from this font's.
# NixOS snowflake geometry: nixos-artwork, CC-BY 4.0.
import json as _json, os as _os
_NIX2 = _json.load(open(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), 'nixos-two-tone.json')))
def _evenodd(rings):
    g = None
    for r in rings:
        p = P(*[tuple(pt) for pt in r]).buffer(0)
        g = p if g is None else g.symmetric_difference(p)
    return g
G['nixos-rest'] = _evenodd(_NIX2['nixos-rest'])
G['nixos-accent'] = _evenodd(_NIX2['nixos-accent'])
NAMES = list(G)

# volume-1 / volume-2 (v2.3, local, 15 October 2026 night): the owner found the bar's speaker "not good": its waves were
# straight bars, so at low volume it read as a media button (a cone and a bar, beside the bar's own previous / next).
# Picked from three rendered in the bar (~/Pictures/volume-compare.png, C): the waves as two 2 px bands of one fan,
# opened 33 degrees each side like the Wi-Fi fan, about (4, 8) inside the cone, 1 px clear of its mouth, ending on
# the live area (x 15). The cone, volume-0 and the muted cross are unchanged.
import math as _m
from shapely.geometry import Point as _Pt
def _wave(cx, cy, r0, r1, half):
    a = _m.radians(half); far = 30
    ring = _Pt(cx, cy).buffer(r1, quad_segs=64).difference(_Pt(cx, cy).buffer(r0, quad_segs=64))
    return ring.intersection(P((cx, cy), (cx + far*_m.cos(a), cy - far*_m.sin(a)), (cx + far*_m.cos(a), cy + far*_m.sin(a))))
_W1 = _wave(4, 8, 6, 8, 33)
_W2 = _wave(4, 8, 9, 11, 33)
G['volume-1'] = U(_SPK2, _W1)
G['volume-2'] = U(_SPK2, _W1, _W2)
NAMES = list(G)
