#ifndef __SMART_MATH_FORMAT_BI__
#define __SMART_MATH_FORMAT_BI__

#include once "Inc\MathParserRawResult.bi"

const SMARTMATH_DECIMALS_MAX = 8
const SMARTMATH_DECIMAL_SEPARATOR_DEFAULT = "."
const SMARTMATH_THOUSANDS_SEPARATOR_DEFAULT = "'"
const SMARTMATH_ARRAY_OUTPUT_SEPARATOR_DEFAULT = ","
const SMARTMATH_RESULT_PREFIX = " = "

declare function FormatResult(byval d as Double) as String
declare function FormatRawResultForDisplay(byref r as RawResult) as String
declare function FormatRawEvaluationResult(byref raw as RawResult) as String

#endif
