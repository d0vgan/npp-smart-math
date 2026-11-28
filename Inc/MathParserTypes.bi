#ifndef __MATHPARSERTYPES_BI__
#define __MATHPARSERTYPES_BI__

'' =============================================================================
''  MathParser numeric type configuration (Basic). Mirror of cpp/MathParserTypes.hpp.
''
''  Every width-specific fact lives here; the rest of the Basic sources use only
''  SmFloat / SmInt / SmUInt, the SmC* conversions and the SM_* constants below.
''
''  RETARGET: change the three types, the SmC* conversions and the float profile in the
''  "type profile" block. Everything else is computed from them.
''  fbc has no integer wider than 64 bits and no float wider than Double, so the only
''  alternative profile shipped here is the narrow one (Single/Long/ULong, built with
''  -d SM_NARROW_TYPES); it exists to prove that nothing outside this file hard-codes a width.
''  factorint keeps its own 64-bit domain (MathParserFactorInt.bas).
'' =============================================================================

'' ---- type profile ------------------------------------------------------------
#ifdef SM_NARROW_TYPES
type SmFloat as Single
type SmInt as Long
type SmUInt as ULong
#define SmCFloat(x) CSng(x)
#define SmCInt(x) CLng(x)
#define SmCUInt(x) CULng(x)
'' Float profile (binary32): mantissa bits, decimal digits that round-trip, max binary/decimal exponent.
#define SM_FLOAT_MANT_DIGITS 24
#define SM_FLOAT_DIGITS10 6
#define SM_FLOAT_DIGITS10_M1 5
#define SM_FLOAT_MAX_EXP2 128
#define SM_FLOAT_MAX_EXP10 38
const SM_FLOAT_MAX as SmFloat = 3.40282347e+38
#else
type SmFloat as Double
type SmInt as LongInt
type SmUInt as ULongInt
#define SmCFloat(x) CDbl(x)
#define SmCInt(x) CLngInt(x)
#define SmCUInt(x) CULngInt(x)
'' Float profile (binary64).
#define SM_FLOAT_MANT_DIGITS 53
#define SM_FLOAT_DIGITS10 15
#define SM_FLOAT_DIGITS10_M1 14
#define SM_FLOAT_MAX_EXP2 1024
#define SM_FLOAT_MAX_EXP10 308
const SM_FLOAT_MAX as SmFloat = 1.7976931348623157e+308
#endif

'' Compile-time assertion: fails to compile (division by zero) when cond is false.
#define SM_STATIC_ASSERT(name, cond) const name as Integer = 1 \ (-(cond))
#define SM_STR_(x) #x
#define SM_STR(x) SM_STR_(x)

SM_STATIC_ASSERT(SM_ASSERT_INT_SIZES, sizeof(SmInt) = sizeof(SmUInt))
SM_STATIC_ASSERT(SM_ASSERT_INT_WIDE_ENOUGH, sizeof(SmInt) >= 4)

'' ---- integer facts ------------------------------------------------------------
const SM_INT_BITS as Integer = sizeof(SmInt) * 8
const SM_UINT_MAX as SmUInt = not cast(SmUInt, 0)
'' 2^(SM_INT_BITS-1): the magnitude of the most negative SmInt.
const SM_INT_MIN_MAG as SmUInt = cast(SmUInt, 1) shl (SM_INT_BITS - 1)
const SM_INT_MAX_U as SmUInt = SM_INT_MIN_MAG - 1
const SM_INT_MAX as SmInt = cast(SmInt, SM_INT_MAX_U)
const SM_INT_MIN as SmInt = -SM_INT_MAX - 1
'' Shift counts are valid in [0, SM_MAX_SHIFT].
const SM_MAX_SHIFT as Integer = SM_INT_BITS - 1
'' Decimal digits: floor(bits * log10(2)) + 1 (log10(2) ~ 30103 / 100000, exact for any realistic width).
const SM_UINT_DIGITS10 as Integer = (SM_INT_BITS * 30103) \ 100000 + 1
'' Largest n with 10^n <= SM_INT_MAX (18 for 64 bits).
const SM_MAX_POW10_EXP_OF_INT as Integer = ((SM_INT_BITS - 1) * 30103) \ 100000
'' 10^0 ... 10^(SM_UINT_DIGITS10 - 1) all fit SmUInt.
const SM_POW10_SMUINT_COUNT as Integer = SM_UINT_DIGITS10
SM_STATIC_ASSERT(SM_ASSERT_INT_SIGNED, (cast(SmInt, SM_UINT_MAX) < 0))
SM_STATIC_ASSERT(SM_ASSERT_INT_MAX_POSITIVE, (SM_INT_MAX > 0))

'' ---- float facts --------------------------------------------------------------
'' Exclusive float bounds: SmInt covers [-SM_FLOAT_SMINT_BOUND, SM_FLOAT_SMINT_BOUND), SmUInt [0, SM_FLOAT_SMUINT_BOUND).
const SM_FLOAT_SMINT_BOUND as SmFloat = 2.0 ^ (SM_INT_BITS - 1)
const SM_FLOAT_SMINT_MIN as SmFloat = -SM_FLOAT_SMINT_BOUND
const SM_FLOAT_SMUINT_BOUND as SmFloat = 2.0 ^ SM_INT_BITS
'' Machine epsilon 2^-(mantissa-1) (2.220446049250313e-16 for Double).
const SM_FLOAT_EPSILON as SmFloat = 2.0 ^ -(SM_FLOAT_MANT_DIGITS - 1)
'' 2^mantissa: the largest magnitude at which every integer is exact (2^53 for Double).
const SM_MAX_EXACT_INT_FROM_FLOAT as SmFloat = 2.0 ^ SM_FLOAT_MANT_DIGITS
'' Bound H for float -> exact promote (MaybeExact): 2^min(|mant/2|, intBits-1). Exclusive upper |v|.
#if (SM_FLOAT_MANT_DIGITS \ 2) < (SM_INT_BITS - 1)
const SM_EXACT_INT_FROM_FLOAT_OP_EXP as Integer = SM_FLOAT_MANT_DIGITS \ 2
#else
const SM_EXACT_INT_FROM_FLOAT_OP_EXP as Integer = SM_INT_BITS - 1
#endif
const SM_MAX_EXACT_INT_FROM_FLOAT_OP as SmFloat = 2.0 ^ SM_EXACT_INT_FROM_FLOAT_OP_EXP
'' True when 2^mantissa exceeds every SmUInt (then every integer magnitude is exactly representable).
const SM_EXACT_LIMIT_COVERS_SMUINT as Boolean = (SM_FLOAT_MANT_DIGITS >= SM_INT_BITS)
'' 2^mantissa as SmUInt (meaningful only when not SM_EXACT_LIMIT_COVERS_SMUINT).
const SM_EXACT_LIMIT_MAG as SmUInt = cast(SmUInt, 1) shl (SM_FLOAT_MANT_DIGITS mod SM_INT_BITS)
'' Significant digits used when printing a non-exact float (digits10 + 1), as a printf "%e" precision.
const SM_FLOAT_DISPLAY_DIGITS as Integer = SM_FLOAT_DIGITS10 + 1
const SM_FMT_SCIENTIFIC_FULL as string = "%." SM_STR(SM_FLOAT_DIGITS10) "e"
'' Short forms (digits10 significant digits) used when they already round-trip, and the magnitude band
'' [10^digits10, 10^(digits10+1)) that always keeps the wider form so the general format's fixed/exponent choice is unchanged.
const SM_FMT_SCIENTIFIC_SHORT as string = "%." SM_STR(SM_FLOAT_DIGITS10_M1) "e"
const SM_FMT_GENERAL_SHORT as string = "%." SM_STR(SM_FLOAT_DIGITS10) "g"
const SM_FLOAT_DISPLAY_BAND_LOW as SmFloat = 10.0 ^ SM_FLOAT_DIGITS10
const SM_FLOAT_DISPLAY_BAND_HIGH as SmFloat = 10.0 ^ (SM_FLOAT_DIGITS10 + 1)

'' ---- tolerances and thresholds (decimal-digit derived) -------------------------
'' Most digits a tolerance may give up: at least 3/5 of SM_FLOAT_DIGITS10 always stay significant, so every
'' tolerance stays well below 1 (Double: 6 of 15, Single: 3 of 6).
const SM_MAX_LOST_DIGITS as Integer = SM_FLOAT_DIGITS10 - (SM_FLOAT_DIGITS10 * 3) \ 5
'' 10^-(SM_FLOAT_DIGITS10 - lostDigits): an absolute tolerance that leaves lostDigits digits of noise room
'' (lostDigits is capped at SM_MAX_LOST_DIGITS).
'' Double: 0 -> 1e-15, 1 -> 1e-14, 2 -> 1e-13, 3 -> 1e-12, 6 -> 1e-9.
#define SM_LOST_CAPPED(n) iif((n) < SM_MAX_LOST_DIGITS, (n), SM_MAX_LOST_DIGITS)
const SM_TOL_LOST0 as SmFloat = 10.0 ^ -(SM_FLOAT_DIGITS10 - SM_LOST_CAPPED(0))
const SM_TOL_LOST1 as SmFloat = 10.0 ^ -(SM_FLOAT_DIGITS10 - SM_LOST_CAPPED(1))
const SM_TOL_LOST2 as SmFloat = 10.0 ^ -(SM_FLOAT_DIGITS10 - SM_LOST_CAPPED(2))
const SM_TOL_LOST3 as SmFloat = 10.0 ^ -(SM_FLOAT_DIGITS10 - SM_LOST_CAPPED(3))
const SM_TOL_LOST6 as SmFloat = 10.0 ^ -(SM_FLOAT_DIGITS10 - SM_LOST_CAPPED(6))
SM_STATIC_ASSERT(SM_ASSERT_TOL_RANGE, SM_TOL_LOST0 > 0 andalso SM_TOL_LOST0 <= SM_TOL_LOST1 andalso SM_TOL_LOST1 <= SM_TOL_LOST2 andalso SM_TOL_LOST2 <= SM_TOL_LOST3 andalso SM_TOL_LOST3 <= SM_TOL_LOST6 andalso SM_TOL_LOST6 < 0.01)
'' hypot switches to the scaled algorithm above this magnitude (1e150 for Double) and below its inverse.
const SM_HYPOT_DIRECT_MAX as SmFloat = 10.0 ^ (SM_FLOAT_MAX_EXP10 \ 2 - 4)
const SM_HYPOT_DIRECT_MIN as SmFloat = 10.0 ^ -(SM_FLOAT_MAX_EXP10 \ 2 - 4)
'' From this magnitude on, asinh and the complex asin/acos paths use their ln(2|z|) asymptotic form, because
'' z * z could overflow. Same value as SM_HYPOT_DIRECT_MAX (squares stay finite below it).
const SM_LARGE_MAGNITUDE_MIN as SmFloat = SM_HYPOT_DIRECT_MAX
'' acosh(z) is ln(2z) from this magnitude on (1e8 for Double): the dropped term 1/(4 z^2) is then below the
'' float rounding noise, so ln(2z) is as accurate as the exact formula and cannot overflow.
const SM_ACOSH_LOG_MIN as SmFloat = 10.0 ^ ((SM_FLOAT_DIGITS10 + 1) \ 2)
'' Start value for "smallest error so far" searches: above any real error, still finite after being
'' multiplied by a denominator up to 1e7 (1e300 for Double).
const SM_HUGE_SENTINEL as SmFloat = 10.0 ^ (SM_FLOAT_MAX_EXP10 - 8)

#ifndef SM_NARROW_TYPES
'' Baseline guards: the default profile must reproduce the historical literals bit for bit.
SM_STATIC_ASSERT(SM_ASSERT_BASE_BITS, SM_INT_BITS = 64)
SM_STATIC_ASSERT(SM_ASSERT_BASE_UINT_MAX, SM_UINT_MAX = &hFFFFFFFFFFFFFFFFULL)
SM_STATIC_ASSERT(SM_ASSERT_BASE_INT_MAX, SM_INT_MAX = 9223372036854775807)
SM_STATIC_ASSERT(SM_ASSERT_BASE_INT_MIN, SM_INT_MIN = -9223372036854775807 - 1)
SM_STATIC_ASSERT(SM_ASSERT_BASE_MIN_MAG, SM_INT_MIN_MAG = &h8000000000000000ULL)
SM_STATIC_ASSERT(SM_ASSERT_BASE_DIGITS, SM_UINT_DIGITS10 = 20 andalso SM_MAX_POW10_EXP_OF_INT = 18 andalso SM_MAX_SHIFT = 63)
SM_STATIC_ASSERT(SM_ASSERT_BASE_SBOUND, SM_FLOAT_SMINT_BOUND = 9223372036854775808.0)
SM_STATIC_ASSERT(SM_ASSERT_BASE_UBOUND, SM_FLOAT_SMUINT_BOUND = 1.8446744073709551616e+19)
SM_STATIC_ASSERT(SM_ASSERT_BASE_EXACT, SM_MAX_EXACT_INT_FROM_FLOAT = 9007199254740992.0)
SM_STATIC_ASSERT(SM_ASSERT_BASE_EXACT_OP, SM_MAX_EXACT_INT_FROM_FLOAT_OP = 67108864.0)
SM_STATIC_ASSERT(SM_ASSERT_BASE_EXACT_MAG, SM_EXACT_LIMIT_MAG = 9007199254740992ULL)
SM_STATIC_ASSERT(SM_ASSERT_BASE_TOL, SM_TOL_LOST0 = 1e-15 andalso SM_TOL_LOST1 = 1e-14 andalso SM_TOL_LOST2 = 1e-13 andalso SM_TOL_LOST3 = 1e-12 andalso SM_TOL_LOST6 = 1e-9)
SM_STATIC_ASSERT(SM_ASSERT_BASE_THRESH, SM_HYPOT_DIRECT_MAX = 1e150 andalso SM_HYPOT_DIRECT_MIN = 1e-150 andalso SM_HUGE_SENTINEL = 1e300 andalso SM_ACOSH_LOG_MIN = 1e8)
SM_STATIC_ASSERT(SM_ASSERT_BASE_DISPLAY, SM_FLOAT_DISPLAY_DIGITS = 16)
SM_STATIC_ASSERT(SM_ASSERT_BASE_EPSILON, SM_FLOAT_EPSILON = 2.2204460492503131e-16)
'' Tests that expect 64-bit / binary64 text are built only under this flag; width-generic suites always run.
#define SM_BASELINE_WIDTHS
#endif

#endif
