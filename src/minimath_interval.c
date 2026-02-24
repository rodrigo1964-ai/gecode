/*
 * minimath_interval.c
 *
 * Aritmética de intervalos cerrados [lo, hi].
 * Convenciones:
 *   - Un intervalo es vacío si lo > hi.
 *   - División con 0 estrictamente en el denominador → [-∞, +∞].
 *   - 0 * ∞ = 0 (convenio de aritmética de intervalos, no IEEE-754).
 */

#include "minimath.h"

/* ── helpers internos ─────────────────────────────────────────────────────── */

static double d_min(double a, double b) { return a < b ? a : b; }
static double d_max(double a, double b) { return a > b ? a : b; }
static double d_min4(double a, double b, double c, double d)
{ return d_min(d_min(a,b), d_min(c,d)); }
static double d_max4(double a, double b, double c, double d)
{ return d_max(d_max(a,b), d_max(c,d)); }

/* 0 * ±∞ = 0 en aritmética de intervalos */
static double safe_mul(double a, double b) {
    if (a == 0.0 || b == 0.0) return 0.0;
    return a * b;
}

/* Producto de dos intervalos usando safe_mul en los 4 extremos */
static MMInterval raw_mul(MMInterval a, MMInterval b) {
    double p0 = safe_mul(a.lo, b.lo);
    double p1 = safe_mul(a.lo, b.hi);
    double p2 = safe_mul(a.hi, b.lo);
    double p3 = safe_mul(a.hi, b.hi);
    MMInterval r;
    r.lo = d_min4(p0,p1,p2,p3);
    r.hi = d_max4(p0,p1,p2,p3);
    return r;
}

/* ── API pública ──────────────────────────────────────────────────────────── */

MMInterval mi_make(double lo, double hi) {
    MMInterval r; r.lo = lo; r.hi = hi; return r;
}

/* Producto por escalar real k */
MMInterval mi_scale(MMInterval iv, double k) {
    MMInterval r;
    if (k >= 0.0) { r.lo = k * iv.lo; r.hi = k * iv.hi; }
    else          { r.lo = k * iv.hi; r.hi = k * iv.lo; }
    return r;
}

/* [a,b] + [c,d] = [a+c, b+d] */
MMInterval mi_add(MMInterval a, MMInterval b) {
    MMInterval r;
    r.lo = a.lo + b.lo;
    r.hi = a.hi + b.hi;
    return r;
}

/* [a,b] - [c,d] = [a-d, b-c] */
MMInterval mi_sub(MMInterval a, MMInterval b) {
    MMInterval r;
    r.lo = a.lo - b.hi;
    r.hi = a.hi - b.lo;
    return r;
}

/* [a,b] * [c,d] = [min, max] de los 4 productos extremo a extremo */
MMInterval mi_mul(MMInterval a, MMInterval b) {
    return raw_mul(a, b);
}

/*
 * [a,b] / [c,d]:
 *   - 0 no en [c,d]:        multiply by [1/d, 1/c]
 *   - c == 0, d > 0:        multiply by [1/d, +∞)
 *   - c < 0, d == 0:        multiply by (-∞, 1/c]
 *   - 0 estrictamente en:   [-∞, +∞]
 *   - [0, 0]:               {NaN, NaN}
 */
MMInterval mi_div(MMInterval a, MMInterval b) {
    double c = b.lo, d = b.hi;
    MMInterval rec;

    if (c == 0.0 && d == 0.0) {
        rec.lo = MI_NAN; rec.hi = MI_NAN;
        return rec;
    }
    if (c > 0.0 || d < 0.0) {
        /* cero fuera del denominador */
        double r0 = 1.0 / c;
        double r1 = 1.0 / d;
        rec.lo = d_min(r0, r1);
        rec.hi = d_max(r0, r1);
        return raw_mul(a, rec);
    }
    if (c == 0.0) {
        /* [0, d>0]: inverso es [1/d, +∞) */
        rec.lo = 1.0 / d; rec.hi = MI_INF;
        return raw_mul(a, rec);
    }
    if (d == 0.0) {
        /* [c<0, 0]: inverso es (-∞, 1/c] */
        rec.lo = -MI_INF; rec.hi = 1.0 / c;
        return raw_mul(a, rec);
    }
    /* 0 estrictamente dentro de [c,d] */
    rec.lo = -MI_INF; rec.hi = MI_INF;
    return rec;
}

/* 1 si x ∈ [lo, hi] */
int mi_contains(MMInterval iv, double x) {
    return (x >= iv.lo && x <= iv.hi) ? 1 : 0;
}

/* 1 si el intervalo es vacío (lo > hi) */
int mi_isempty(MMInterval iv) {
    return (iv.lo > iv.hi) ? 1 : 0;
}

/* 1 si lo y hi son números finitos no-NaN */
int mi_isvalid(MMInterval iv) {
    return (iv.lo == iv.lo && iv.hi == iv.hi) ? 1 : 0;
}

/* Intersección: [max(a.lo,b.lo), min(a.hi,b.hi)]; puede quedar vacía */
MMInterval mi_intersect(MMInterval a, MMInterval b) {
    MMInterval r;
    r.lo = d_max(a.lo, b.lo);
    r.hi = d_min(a.hi, b.hi);
    return r;
}

/* Hull (menor intervalo que contiene a ambos) */
MMInterval mi_hull(MMInterval a, MMInterval b) {
    MMInterval r;
    r.lo = d_min(a.lo, b.lo);
    r.hi = d_max(a.hi, b.hi);
    return r;
}

/* Ancho del intervalo: hi - lo */
double mi_width(MMInterval iv) {
    return iv.hi - iv.lo;
}

/* Punto medio: (lo + hi) / 2 */
double mi_midpoint(MMInterval iv) {
    return (iv.lo + iv.hi) * 0.5;
}
