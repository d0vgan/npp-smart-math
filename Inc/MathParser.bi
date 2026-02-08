#ifndef MATHPARSER_H
#define MATHPARSER_H

' Declara las funciones publicas del motor matematico
declare sub Parser_ClearVariables()
declare function Parser_TryEvaluate(byval s as zstring ptr, byref result as double) as boolean

#endif