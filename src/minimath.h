/* minimath.h — declaraciones de MiniMath sin libm */
#ifndef MINIMATH_H
#define MINIMATH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Trigonometricas */
double mm_sin(double x);
double mm_cos(double x);
double mm_tan(double x);
double mm_arcsin(double x);
double mm_arccos(double x);
double mm_arctan(double x);
double mm_arctan2(double y, double x);
double mm_hypot(double a, double b);

/* Exponenciales / logaritmicas */
double mm_exp(double x);
double mm_ln(double x);
double mm_log2(double x);
double mm_log10(double x);
double mm_logn(double base, double x);
double mm_pow(double base, double exp);
double mm_sqrt(double x);

/* Utilidades */
double mm_floor(double x);
double mm_ceil(double x);
double mm_fabs(double x);
double mm_sign(double x);
double mm_fmax(double a, double b);
double mm_fmin(double a, double b);
double mm_ifthen_d(int cond, double a, double b);

/* Complejos */
typedef struct { double re; double im; } MMComplex;

MMComplex mc_make(double re, double im);
MMComplex mc_from_polar(double r, double theta);
double    mc_abs(MMComplex z);
double    mc_arg(MMComplex z);
MMComplex mc_conj(MMComplex z);
MMComplex mc_neg(MMComplex z);
MMComplex mc_scale(MMComplex z, double s);

MMComplex mc_add(MMComplex a, MMComplex b);
MMComplex mc_sub(MMComplex a, MMComplex b);
MMComplex mc_mul(MMComplex a, MMComplex b);
MMComplex mc_div(MMComplex a, MMComplex b);

MMComplex mc_exp(MMComplex z);
MMComplex mc_ln(MMComplex z);
MMComplex mc_sqrt(MMComplex z);
MMComplex mc_pow(MMComplex base, MMComplex exponent);
MMComplex mc_sin(MMComplex z);
MMComplex mc_cos(MMComplex z);
MMComplex mc_tan(MMComplex z);

int mc_isnan(MMComplex z);
int mc_isinf(MMComplex z);
int mc_iszero(MMComplex z);

#ifdef __cplusplus
}
#endif

/* ── Aritmética de intervalos ─────────────────────────────────────────────── */

typedef struct { double lo; double hi; } MMInterval;

/* Constantes portables */
#ifndef MI_INF
#  include <math.h>
#  define MI_INF  (1.0/0.0)
#  define MI_NAN  (0.0/0.0)
#endif

MMInterval mi_make    (double lo, double hi);
MMInterval mi_scale   (MMInterval iv, double k);
MMInterval mi_add     (MMInterval a, MMInterval b);
MMInterval mi_sub     (MMInterval a, MMInterval b);
MMInterval mi_mul     (MMInterval a, MMInterval b);
MMInterval mi_div     (MMInterval a, MMInterval b);
int        mi_contains(MMInterval iv, double x);
int        mi_isempty (MMInterval iv);
int        mi_isvalid (MMInterval iv);
MMInterval mi_intersect(MMInterval a, MMInterval b);
MMInterval mi_hull    (MMInterval a, MMInterval b);
double     mi_width   (MMInterval iv);
double     mi_midpoint(MMInterval iv);

#endif /* MINIMATH_H */
