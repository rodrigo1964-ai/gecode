#include <stdint.h>

typedef union { double d; uint64_t u; } T64;

/* Helper: detect NaN via bit pattern (exponent all 1s, mantissa != 0) */
static int _is_nan(double x) {
    T64 v;
    v.d = x;
    return ((v.u & 0x7FF0000000000000ULL) == 0x7FF0000000000000ULL) &&
           ((v.u & 0x000FFFFFFFFFFFFFULL) != 0);
}

/*
 * mm_floor: floor via IEEE 754 bit manipulation, no libm.
 *
 * Strategy:
 *   - biased = raw 11-bit exponent field; e = biased - 1023 (unbiased exponent)
 *   - e >= 52  : value already integer (or Inf/NaN) — return as-is.
 *   - biased==0: subnormal or ±0 — floor(+tiny)=0, floor(-tiny)=-1, ±0→0.
 *   - e < 0    : |x| < 1, not subnormal — same rule: pos→0, neg→-1.
 *   - 0<=e<52  : mask off the (52-e) fractional mantissa bits (truncate toward 0),
 *                then if x was negative and we discarded bits, subtract 1.
 */
double mm_floor(double x) {
    T64 v;
    v.d = x;
    int biased = (int)((v.u >> 52) & 0x7FF);
    int e = biased - 1023;

    /* Already integer, Inf, or NaN */
    if (e >= 52) return x;

    /* Subnormals and ±0 */
    if (biased == 0) {
        if (x < 0.0) return -1.0;
        return 0.0;
    }

    /* −1 < x < 1  (normal, |x| < 1) */
    if (e < 0) {
        if (x < 0.0) return -1.0;
        return 0.0;
    }

    /* 0 <= e < 52: mask fractional bits */
    uint64_t frac_mask = (uint64_t)0x000FFFFFFFFFFFFFULL >> e;
    uint64_t int_bits  = v.u & ~frac_mask;

    T64 trunc_v;
    trunc_v.u = int_bits;
    double trunc_x = trunc_v.d;

    /* For negative values, if fractional bits were non-zero, round down */
    if (x < 0.0 && (v.u & frac_mask) != 0)
        return trunc_x - 1.0;

    return trunc_x;
}

/*
 * mm_ceil: ceil(x) == -floor(-x)
 */
double mm_ceil(double x) {
    return -mm_floor(-x);
}

/*
 * mm_fabs: absolute value via sign-bit clear.
 */
double mm_fabs(double x) {
    T64 v;
    v.d = x;
    v.u &= 0x7FFFFFFFFFFFFFFFULL;
    return v.d;
}

/*
 * mm_sign: FPC Math.Sign semantics.
 *   NaN → 0.0,  x > 0 → 1.0,  x < 0 → -1.0,  x == 0 → 0.0
 */
double mm_sign(double x) {
    if (_is_nan(x)) return 0.0;
    if (x > 0.0)    return  1.0;
    if (x < 0.0)    return -1.0;
    return 0.0;
}

/*
 * mm_fmax: max(a, b).
 * If either operand is NaN, return the other.
 */
double mm_fmax(double a, double b) {
    if (_is_nan(a)) return b;
    if (_is_nan(b)) return a;
    return (a >= b) ? a : b;
}

/*
 * mm_fmin: min(a, b).
 * If either operand is NaN, return the other.
 */
double mm_fmin(double a, double b) {
    if (_is_nan(a)) return b;
    if (_is_nan(b)) return a;
    return (a <= b) ? a : b;
}

/*
 * mm_ifthen_d: IfThen(Boolean, Double, Double)
 *   cond != 0 -> a,  cond == 0 -> b
 */
double mm_ifthen_d(int cond, double a, double b) {
    return cond ? a : b;
}
