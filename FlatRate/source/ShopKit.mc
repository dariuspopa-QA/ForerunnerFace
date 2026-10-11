import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Shared by the Shop Floor faces for mechanics (SocketSet, TachCluster, ObdScanner, LugStar,
// FlatRate; copied unchanged per project). Geometry is in design pixels of the 454 x 454
// canvas; s = width / 454.
module ShopKit {

    const GROUND = 0x050505;
    const TEXT = 0xF2F2F0;
    const MUTED = 0x8D939A;
    const SOFT = 0xC9CCD0;
    const DIM = 0x26282B;
    const STEEL = 0x5C6168;
    const DARK_STEEL = 0x3A3D41;
    const RED = 0xE83A3A;
    const AOD_TEXT = 0xA9AEB4;

    // Always-On drift against burn-in: a few px, a new spot every minute
    const SHIFTS = [[0, 0], [3, 2], [-2, 3], [2, -3], [-3, -1], [1, 3], [-1, -3], [3, -1]];

    function shift(minute as Number) as Array<Number> {
        return SHIFTS[minute % SHIFTS.size()] as Array<Number>;
    }

    // Screen point (px) at clock angle deg (0 = 12 o'clock, clockwise), radius r from
    // (cx, cy) and x along the tangent (clockwise positive); all in design px.
    function polar(deg as Numeric, r as Numeric, x as Numeric, cx as Numeric, cy as Numeric, s as Float) as [Float, Float] {
        var a = Math.toRadians(deg);
        var sn = Math.sin(a);
        var cs = Math.cos(a);
        return [((cx + x * cs + r * sn) * s).toFloat(), ((cy + x * sn - r * cs) * s).toFloat()];
    }

    // A radial bar from radius r0 to r1, w wide, around the screen centre.
    function bar(dc as Dc, deg as Numeric, r0 as Numeric, r1 as Numeric, w as Numeric, s as Float) as Void {
        var h = w / 2.0f;
        var c = FaceKit.C;
        dc.fillPolygon([polar(deg, r0, -h, c, c, s), polar(deg, r1, -h, c, c, s),
            polar(deg, r1, h, c, c, s), polar(deg, r0, h, c, c, s)]);
    }

    // Pointy-top hexagon (a nut or a socket's hex) around design point (cx, cy).
    function hexagon(cx as Numeric, cy as Numeric, r as Numeric, s as Float) as Array<[Float, Float]> {
        var pts = new Array<[Float, Float]>[6];
        for (var i = 0; i < 6; i++) {
            pts[i] = polar(i * 60, r, 0, cx, cy, s);
        }
        return pts;
    }

    // Closed outline through px points.
    function outline(dc as Dc, pts as Array<[Float, Float]>) as Void {
        var n = pts.size();
        for (var i = 0; i < n; i++) {
            var a = pts[i];
            var b = pts[(i + 1) % n];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
    }

    // Dashed line in px.
    function dashed(dc as Dc, x1 as Float, y1 as Float, x2 as Float, y2 as Float, dash as Float, gap as Float) as Void {
        var dx = x2 - x1;
        var dy = y2 - y1;
        var len = Math.sqrt(dx * dx + dy * dy).toFloat();
        if (len < 1) {
            return;
        }
        var ux = dx / len;
        var uy = dy / len;
        for (var d = 0.0f; d < len; d += dash + gap) {
            var e = d + dash > len ? len : d + dash;
            dc.drawLine(x1 + ux * d, y1 + uy * d, x1 + ux * e, y1 + uy * e);
        }
    }

    // Plain rectangle with rounded corners in design px.
    function box(dc as Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric, r as Numeric, s as Float) as Void {
        dc.fillRoundedRectangle(x * s, y * s, w * s, h * s, r * s);
    }

    // Watch battery 0..100 (fixed in demo builds).
    function battery() as Number {
        return FaceDemo.battery(Math.round(System.getSystemStats().battery).toNumber());
    }

    // The watch battery as a car battery's resting voltage: 0 % = 11.8 V, 100 % = 12.7 V.
    function volts(pct as Number) as String {
        return (11.8f + 0.9f * pct / 100.0f).format("%.1f");
    }

    function orDash(n as Number or Null) as String {
        return n != null ? n.toString() : "--";
    }
}
