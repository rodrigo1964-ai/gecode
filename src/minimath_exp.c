/*
 * minimath_exp.c - Exponential and logarithmic functions in pure C, no libm.
 *
 * Functions exported for linking with Pascal (FPC):
 *   mm_exp, mm_ln, mm_log2, mm_log10, mm_logn, mm_pow, mm_sqrt
 *
 * Compile: gcc -c -O2 -std=c99 src/minimath_exp.c -o obj/minimath_exp.o
 * No libm. Only #include <stdint.h>.
 */

#include <stdint.h>

typedef union { double d; uint64_t u; } T64;

static int ieee_exp_field(double x)
{
    T64 v; v.d = x;
    return (int)((v.u >> 52) & 0x7FFU) - 1023;
}

static double ieee_mant(double x)
{
    T64 v; v.d = x;
    v.u = (v.u & 0x000FFFFFFFFFFFFFULL) | 0x3FF0000000000000ULL;
    return v.d;
}

static double ldexp2(double x, int n)
{
    T64 v; v.d = x;
    v.u += (uint64_t)((int64_t)n << 52);
    return v.d;
}

static double pos_inf(void) { T64 v; v.u = 0x7FF0000000000000ULL; return v.d; }
static double neg_inf(void) { T64 v; v.u = 0xFFF0000000000000ULL; return v.d; }
static double nan_val(void) { T64 v; v.u = 0x7FF8000000000000ULL; return v.d; }

#define LN2     0.6931471805599453094172321
#define LOG2E   1.4426950408889634073599247
#define LN10    2.3025850929940456840179915
#define SQRT2   1.4142135623730950488016887

/*
 * mm_ln(x) -- natural logarithm, full double precision
 *
 * 1. Decompose x = m * 2^e,  m in [1, 2).
 * 2. If m >= sqrt(2): m /= 2, e += 1  ->  m in [1/sqrt2, sqrt2].
 * 3. f = (m-1)/(m+1),  |f| <= (sqrt2-1)/(sqrt2+1) ~ 0.171.
 * 4. ln(m) = 2*atanh(f) = 2f*(1 + f^2/3 + f^4/5 + ... + f^20/11).
 *    10 terms: error < 2*f^21/21 < 2*(0.171)^21/21 ~ 1e-17. Full precision.
 * 5. ln(x) = ln(m) + e * ln(2).
 */
double mm_ln(double x)
{
    T64 bits;
    int e;
    double m, f, f2, r;

    bits.d = x;

    if (x != x)                          return nan_val();
    if (bits.u == 0x7FF0000000000000ULL) return pos_inf();
    if (x == 0.0)                        return neg_inf();
    if (x < 0.0)                         return nan_val();

    e = ieee_exp_field(x);
    m = ieee_mant(x);

    if (m >= SQRT2) { m *= 0.5; e += 1; }

    f  = (m - 1.0) / (m + 1.0);
    f2 = f * f;

    /* Horner for 2f*(1 + f^2/3 + f^4/5 + ... + f^20/11), 10 terms */
    r = 1.0/21.0;
    r = 1.0/19.0 + f2 * r;
    r = 1.0/17.0 + f2 * r;
    r = 1.0/15.0 + f2 * r;
    r = 1.0/13.0 + f2 * r;
    r = 1.0/11.0 + f2 * r;
    r = 1.0/ 9.0 + f2 * r;
    r = 1.0/ 7.0 + f2 * r;
    r = 1.0/ 5.0 + f2 * r;
    r = 1.0/ 3.0 + f2 * r;
    r = 1.0       + f2 * r;
    r = 2.0 * f * r;

    return r + (double)e * LN2;
}

/*
 * mm_exp(x) -- e^x, full double precision
 *
 * Algorithm:
 * 1. n = round(x / ln2), so x = n*ln2 + r, |r| <= ln2/2 ~ 0.347.
 * 2. exp(x) = 2^n * exp(r).
 * 3. 2^n exact via ldexp2.
 * 4. exp(r) via Taylor series (14 terms): error < 0.347^15/15! ~ 2e-18. Full precision.
 */
double mm_exp(double x)
{
    double n_d, r, p;
    int    n;

    if (x >  709.7827128933840)  return pos_inf();
    if (x < -745.1332191019411)  return 0.0;
    if (x == 0.0)                return 1.0;

    /* n = round(x / ln2) */
    n_d = x * (1.0 / LN2);
    n   = (int)(n_d + (n_d >= 0.0 ? 0.5 : -0.5));
    /* r = x - n*ln2, small */
    r   = x - (double)n * LN2;

    /*
     * exp(r) via Horner, 14 terms of Taylor series:
     * exp(r) = 1 + r*(1 + r/2*(1 + r/3*(1 + r/4*(1 + r/5*(1 + r/6*(1 +
     *           r/7*(1 + r/8*(1 + r/9*(1 + r/10*(1 + r/11*(1 + r/12*(1 +
     *           r/13*(1 + r/14))))))))))))))
     */
    p = 1.0 + r * (1.0 / 14.0);
    p = 1.0 + r * (1.0 / 13.0) * p;
    p = 1.0 + r * (1.0 / 12.0) * p;
    p = 1.0 + r * (1.0 / 11.0) * p;
    p = 1.0 + r * (1.0 / 10.0) * p;
    p = 1.0 + r * (1.0 /  9.0) * p;
    p = 1.0 + r * (1.0 /  8.0) * p;
    p = 1.0 + r * (1.0 /  7.0) * p;
    p = 1.0 + r * (1.0 /  6.0) * p;
    p = 1.0 + r * (1.0 /  5.0) * p;
    p = 1.0 + r * (1.0 /  4.0) * p;
    p = 1.0 + r * (1.0 /  3.0) * p;
    p = 1.0 + r * (1.0 /  2.0) * p;
    p = 1.0 + r * p;

    return ldexp2(p, n);
}

double mm_log2(double x)  { return mm_ln(x) * LOG2E; }
double mm_log10(double x) { return mm_ln(x) * (1.0 / LN10); }
double mm_logn(double base, double x) { return mm_ln(x) / mm_ln(base); }

/*
 * mm_sqrt(x) -- Newton-Raphson square root, 4 iterations
 */
double mm_sqrt(double x)
{
    T64 bits;
    double r;

    if (x != x)   return nan_val();
    if (x < 0.0)  return nan_val();
    if (x == 0.0) return 0.0;
    bits.d = x;
    if (bits.u == 0x7FF0000000000000ULL) return pos_inf();

    bits.u = (bits.u >> 1) + 0x1FF8000000000000ULL;
    r = bits.d;

    r = 0.5 * (r + x / r);
    r = 0.5 * (r + x / r);
    r = 0.5 * (r + x / r);
    r = 0.5 * (r + x / r);

    return r;
}

/* Returns 1 if d is odd integer, 2 if even integer, 0 if non-integer */
static int int_parity(double d)
{
    int64_t n;
    double  t;
    if (d < -9007199254740992.0 || d > 9007199254740992.0) return 2;
    n = (int64_t)d;
    t = d - (double)n;
    if (t != 0.0) return 0;
    return (n & 1) ? 1 : 2;
}

/*
 * mm_pow(base, exp) -- base^exp = exp(exp * ln(base))
 */
double mm_pow(double base, double exp)
{
    int    parity;
    double result;

    if (exp  == 0.0) return 1.0;
    if (base == 1.0) return 1.0;
    if (exp  == 1.0) return base;
    if (base != base || exp != exp) return nan_val();

    if (base < 0.0) {
        parity = int_parity(exp);
        if (parity == 0) return nan_val();
        result = mm_exp(exp * mm_ln(-base));
        return (parity == 1) ? -result : result;
    }

    if (base == 0.0)
        return (exp > 0.0) ? 0.0 : pos_inf();

    return mm_exp(exp * mm_ln(base));
}
