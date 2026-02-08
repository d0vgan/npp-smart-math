#include "crt.bi"
#include "Inc\MathParser.bi"

type VarEntry
  name as string
  value as double
end type

dim shared as VarEntry variables()
dim shared as zstring ptr pStream
dim shared as integer parseError
dim shared as boolean wasPercentage

private sub SkipSpaces()
  while (*pStream = 32) or (*pStream = 9) or (*pStream = 10) or (*pStream = 13)
    pStream += 1
  wend
end sub

private function GetVariable(byref n as string, byref v as double) as boolean
  dim as integer i
  for i = lbound(variables) to ubound(variables)
    if variables(i).name = n then
      v = variables(i).value
      return TRUE
    end if
  next i
  return FALSE
end function

private sub SetVariable(byref n as string, v as double)
  dim as integer i
  for i = lbound(variables) to ubound(variables)
    if variables(i).name = n then
      variables(i).value = v
      exit sub
    end if
  next i
  if ubound(variables) = -1 then
    redim variables(0)
  else
    redim preserve variables(ubound(variables) + 1)
  end if
  variables(ubound(variables)).name = n
  variables(ubound(variables)).value = v
end sub

declare function ParseExpression() as double

private function ParseFactor() as double
  dim as double n = 0
  wasPercentage = FALSE
  
  SkipSpaces()
  if (*pStream >= 48 and *pStream <= 57) then
    dim as zstring ptr pEnd
    n = strtod(pStream, @pEnd)
    pStream = pEnd
  elseif (*pStream >= 65 and *pStream <= 90) or (*pStream >= 97 and *pStream <= 122) or (*pStream = 95) then
    dim as zstring ptr pStart = pStream
    while (*pStream >= 65 and *pStream <= 90) or (*pStream >= 97 and *pStream <= 122) or (*pStream >= 48 and *pStream <= 57) or (*pStream = 95)
      pStream += 1
    wend
    dim as string varName = left(*pStart, pStream - pStart)
    if GetVariable(varName, n) = FALSE then parseError = 1
  elseif *pStream = 40 then
    pStream += 1
    n = ParseExpression()
    SkipSpaces()
    if *pStream = 41 then pStream += 1 else parseError = 1
  else
    parseError = 1
  end if
  
  SkipSpaces()
  if *pStream = 37 then
    pStream += 1
    n = n / 100.0
    wasPercentage = TRUE
  end if
  return n
end function

private function ParseTerm() as double
  dim as double n = ParseFactor()
  SkipSpaces()
  while (*pStream = 42) or (*pStream = 47)
    if parseError then exit while
    dim as ubyte op = *pStream
    pStream += 1
    dim as double n2 = ParseFactor()
    if op = 42 then
      n *= n2
    else
      if n2 = 0 then parseError = 1 else n /= n2
    end if
    wasPercentage = FALSE
    SkipSpaces()
  wend
  return n
end function

private function ParseExpression() as double
  dim as double n = ParseTerm()
  SkipSpaces()
  while (*pStream = 43) or (*pStream = 45)
    if parseError then exit while
    dim as ubyte op = *pStream
    pStream += 1
    dim as double n2 = ParseTerm()
    
    if wasPercentage then
      SkipSpaces()
      if (*pStream = 0) or (*pStream = 41) then
        n2 = n * n2
      end if
    end if
    
    if op = 43 then n += n2 else n -= n2
    SkipSpaces()
  wend
  return n
end function

sub Parser_ClearVariables()
  erase variables
end sub

function Parser_TryEvaluate(byval s as zstring ptr, byref result as double) as boolean
  pStream = s
  parseError = 0
  
  SkipSpaces()
  dim as zstring ptr pStart = pStream
  if (*pStream >= 65 and *pStream <= 90) or (*pStream >= 97 and *pStream <= 122) or (*pStream = 95) then
    while (*pStream >= 65 and *pStream <= 90) or (*pStream >= 97 and *pStream <= 122) or (*pStream >= 48 and *pStream <= 57) or (*pStream = 95)
      pStream += 1
    wend
    dim as string varName = left(*pStart, pStream - pStart)
    SkipSpaces()
    if *pStream = 61 then
      pStream += 1
      result = ParseExpression()
      SkipSpaces()
      if *pStream = 0 and parseError = 0 then
        SetVariable(varName, result)
        return TRUE
      end if
      return FALSE
    end if
  end if
  
  pStream = s
  parseError = 0
  result = ParseExpression()
  SkipSpaces()
  if *pStream <> 0 then parseError = 1
  if parseError = 1 then return FALSE
  return TRUE
end function