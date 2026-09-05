#include "windows.bi"
#include "crt.bi"
#include "Inc\PluginInterface.bi"
#include "Inc\MathParser.bi"
#include "Inc\ConfigManager.bi"
#include "Inc\Smart-Math-Format.bi"
#include "Inc\Smart-Math-CopyNormalize.bi"

const PLUGIN_NAME = wstr("Smart Math Plugin")
const TB_BMP_ID = 100
const TB_ICON_LIGHT_ID = 101
const TB_ICON_DARK_ID = 102
const IDX_TOGGLE = 0
const IDX_SEPARATOR = 1
const IDX_PREC0 = 2
const IDX_COMPLEX = 11
const IDX_SHOWERRORS = 12
const NB_FUNC = 13
const SCI_GETFIRSTVISIBLELINE = 2152
const SCI_GETLINECOUNT = 2154
const SCI_GETLINE = 2153
const SCI_LINELENGTH = 2350
const SCI_POSITIONFROMLINE = 2167
const SCI_GETCURRENTPOS = 2008
const SCI_SETEMPTYSELECTION = 2556
const SCI_GETLINEENDPOSITION = 2136
const SCI_POINTXFROMPOSITION = 2164
const SCI_POINTYFROMPOSITION = 2165
const SCI_TEXTHEIGHT = 2279
const SCI_DOCLINEFROMVISIBLE = 2221
const SCI_EOLANNOTATIONSETTEXT = 2740
const SCI_EOLANNOTATIONGETTEXT = 2741
const SCI_EOLANNOTATIONSETSTYLE = 2742
const SCI_EOLANNOTATIONCLEARALL = 2744
const SCI_EOLANNOTATIONSETVISIBLE = 2745
const SCI_EOLANNOTATIONSETSTYLEOFFSET = 2747
const SCI_EOLANNOTATIONGETSTYLEOFFSET = 2748
const SCI_STYLESETFORE = 2051
const SCI_STYLEGETFORE = 2481
const SCI_ALLOCATEEXTENDEDSTYLES = 2553
const SCI_GETMODEVENTMASK = 2378
const SCI_SETMODEVENTMASK = 2359
const STYLE_BRACEBAD = 35
const ANN_STYLE_DEFAULT = 0
const ANN_STYLE_ERROR = 1
const EOLANNOTATION_STANDARD = 1
const EOLANNOTATION_HIDDEN = 0
const SCN_DOUBLECLICK = 2006
const SCN_MODIFIED = 2008
const SC_MOD_INSERTTEXT = &h1
const SC_MOD_DELETETEXT = &h2
const SC_MOD_TEXT_FLAGS = (SC_MOD_INSERTTEXT or SC_MOD_DELETETEXT)
#ifndef CF_UNICODETEXT
const CF_UNICODETEXT = 13
#endif
#ifndef CP_UTF8
const CP_UTF8 = 65001
#endif
const NPPM_GETFULLPATHFROMBUFFERID = (NPPMSG + 58)
const NPPM_GETCURRENTBUFFERID = (NPPMSG + 60)

dim shared as HINSTANCE hInst
dim shared as NppData nppData
dim shared as FuncItem funcItems(NB_FUNC - 1)
dim shared as boolean isNppClosing = FALSE
dim shared as WNDPROC oldSciProc = 0
dim shared as boolean g_cacheReady = FALSE
dim shared as string g_cachePath
redim shared g_annText(0 to 0) as string
redim shared g_cachedLineText(0 to 0) as string
redim shared g_cachedResult(0 to 0) as string

declare sub UpdateAnnotations(byval forceFull as boolean = FALSE)
declare sub SetPrecision(p as integer)
declare function CopyResultForLine(byval hScintilla as HWND, byval lineIdx as integer) as boolean
declare function SciSubclassProc(byval hWnd as HWND, byval uMsg as UINT, byval wParam as WPARAM, byval lParam as LPARAM) as LRESULT

sub DllLoad() constructor
  const cFlags = GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS or GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT
  GetModuleHandleEx(cFlags, cast(any ptr, @DllLoad), @hInst)
end sub

function FindMyPluginMenu() as HMENU
  dim as HMENU hMain = GetMenu(nppData._nppHandle)
  dim as integer i, j, k
  dim as HMENU hSub, hDeep
  dim as integer targetID = funcItems(0)._cmdID
  
  for i = 0 to GetMenuItemCount(hMain) - 1
    hSub = GetSubMenu(hMain, i)
    if hSub <> 0 then
      for j = 0 to GetMenuItemCount(hSub) - 1
        hDeep = GetSubMenu(hSub, j)
        if hDeep <> 0 then
          for k = 0 to GetMenuItemCount(hDeep) - 1
            if GetMenuItemID(hDeep, k) = targetID then
              return hDeep
            end if
          next k
        end if
      next j
    end if
  next i
  return 0
end function

sub OrganizeMenu()
  dim as HMENU hMyMenu = FindMyPluginMenu()
  if hMyMenu = 0 then exit sub
  
  dim as HMENU hSubMenuDecimal = CreatePopupMenu()
  dim as integer i
  
  for i = 0 to 8
    RemoveMenu(hMyMenu, funcItems(IDX_PREC0 + i)._cmdID, MF_BYCOMMAND)
    AppendMenu(hSubMenuDecimal, MF_STRING, funcItems(IDX_PREC0 + i)._cmdID, wstr(str(i)))
  next i
  
  AppendMenu(hMyMenu, MF_STRING or MF_POPUP, cast(UINT_PTR, hSubMenuDecimal), wstr("Decimal Places"))
  ModifyMenu(hMyMenu, funcItems(IDX_SEPARATOR)._cmdID, MF_BYCOMMAND or MF_SEPARATOR, funcItems(IDX_SEPARATOR)._cmdID, NULL)
  DrawMenuBar(nppData._nppHandle)
  SetPrecision(Config_GetDecimalPlaces())
  SendMessage(nppData._nppHandle, NPPM_SETMENUITEMCHECK, funcItems(IDX_COMPLEX)._cmdID, iif(Config_GetSupportComplexNumbers(), 1, 0))
  SendMessage(nppData._nppHandle, NPPM_SETMENUITEMCHECK, funcItems(IDX_SHOWERRORS)._cmdID, iif(Config_GetShowErrors(), 1, 0))
end sub

function GetCurrentPath() as string
  dim as integer bufferID
  dim as wstring * MAX_PATH fullPath
  bufferID = SendMessage(nppData._nppHandle, NPPM_GETCURRENTBUFFERID, 0, 0)
  SendMessage(nppData._nppHandle, NPPM_GETFULLPATHFROMBUFFERID, bufferID, cast(LPARAM, @fullPath))
  return str(fullPath)
end function

function GetCurrentScintilla() as HWND
  dim as integer iCurView
  if nppData._nppHandle = 0 then return 0
  iCurView = SendMessage(nppData._nppHandle, NPPM_GETCURRENTVIEW, 0, 0)
  if iCurView = 0 then return nppData._scintillaMainHandle
  return nppData._scintillaSecondHandle
end function

function GetScintillaLineText(byval hScintilla as HWND, byval lineIdx as integer) as string
  dim as integer lineBufLen, iStart, iEnd, lineContentLen
  dim as zstring ptr pLineBuf
  dim as string sLine

  lineBufLen = SendMessage(hScintilla, SCI_LINELENGTH, lineIdx, 0)
  if lineBufLen <= 0 then return ""
  iStart = SendMessage(hScintilla, SCI_POSITIONFROMLINE, lineIdx, 0)
  iEnd = SendMessage(hScintilla, SCI_GETLINEENDPOSITION, lineIdx, 0)
  lineContentLen = iEnd - iStart

  pLineBuf = callocate(lineBufLen + 1)
  SendMessage(hScintilla, SCI_GETLINE, lineIdx, cast(LPARAM, pLineBuf))
  if lineContentLen < lineBufLen then
    pLineBuf[lineContentLen] = 0
  else
    pLineBuf[lineBufLen] = 0
  end if
  sLine = *pLineBuf
  deallocate(pLineBuf)
  return sLine
end function

function DisplayTextFromEval(byref sLine as string) as string
  dim as RawResult raw
  dim as string sRes, sErr
  if Parser_TryEvaluateExRaw(sLine, raw) then
    sRes = FormatRawEvaluationResult(raw)
    if Len(sRes) > 0 then return sRes
  else
    sErr = Parser_GetLastError()
    if Len(sErr) = 0 then return ""
    if Config_GetShowErrors() orelse Parser_IsFunctionHintError(sErr) then
      return SMARTMATH_ERROR_PREFIX & sErr
    end if
  end if
  return ""
end function

function GetEolAnnotationText(byval hScintilla as HWND, byval lineIdx as integer) as string
  dim as integer nLen, nGot, nAlloc
  dim as zstring ptr pBuf
  dim as string sText
  if (hScintilla = 0) orelse (lineIdx < 0) then return ""
  nLen = SendMessage(hScintilla, SCI_EOLANNOTATIONGETTEXT, lineIdx, 0)
  if nLen < 0 then nLen = 0
  if nLen > 65536 then nLen = 65536
  nAlloc = nLen
  if nAlloc < 1 then nAlloc = 4096
  pBuf = callocate(nAlloc + 1)
  if pBuf = 0 then return ""
  nGot = SendMessage(hScintilla, SCI_EOLANNOTATIONGETTEXT, lineIdx, cast(LPARAM, pBuf))
  if nGot <= 0 then
    deallocate(pBuf)
    return ""
  end if
  if nGot > nAlloc then nGot = nAlloc
  pBuf[nGot] = 0
  sText = *pBuf
  deallocate(pBuf)
  return sText
end function

function LineFromClientY(byval hScintilla as HWND, byval y as integer) as integer
  dim as integer lineH, firstVis, firstDoc, firstPos, y0, vis, nLines, lineIdx
  if hScintilla = 0 then return 0
  nLines = SendMessage(hScintilla, SCI_GETLINECOUNT, 0, 0)
  if nLines <= 0 then return 0
  lineH = SendMessage(hScintilla, SCI_TEXTHEIGHT, 0, 0)
  if lineH < 1 then lineH = 1
  firstVis = SendMessage(hScintilla, SCI_GETFIRSTVISIBLELINE, 0, 0)
  firstDoc = SendMessage(hScintilla, SCI_DOCLINEFROMVISIBLE, firstVis, 0)
  firstPos = SendMessage(hScintilla, SCI_POSITIONFROMLINE, firstDoc, 0)
  y0 = SendMessage(hScintilla, SCI_POINTYFROMPOSITION, 0, firstPos)
  vis = firstVis + (y - y0) \ lineH
  if vis < 0 then vis = 0
  lineIdx = SendMessage(hScintilla, SCI_DOCLINEFROMVISIBLE, vis, 0)
  if lineIdx < 0 then lineIdx = 0
  if lineIdx >= nLines then lineIdx = nLines - 1
  return lineIdx
end function

function TryCopyResultAtClientPoint(byval hScintilla as HWND, byval x as integer, byval y as integer) as boolean
  dim as integer lineIdx, lineEnd, xLineEnd, caretPos
  if hScintilla = 0 then return FALSE
  lineIdx = LineFromClientY(hScintilla, y)
  lineEnd = SendMessage(hScintilla, SCI_GETLINEENDPOSITION, lineIdx, 0)
  xLineEnd = SendMessage(hScintilla, SCI_POINTXFROMPOSITION, 0, lineEnd)
  if x < xLineEnd then return FALSE
  if CopyResultForLine(hScintilla, lineIdx) = FALSE then return FALSE
  caretPos = SendMessage(hScintilla, SCI_GETCURRENTPOS, 0, 0)
  SendMessage(hScintilla, SCI_SETEMPTYSELECTION, caretPos, 0)
  return TRUE
end function

function SciSubclassProc(byval hWnd as HWND, byval uMsg as UINT, byval wParam as WPARAM, byval lParam as LPARAM) as LRESULT
  if uMsg = WM_LBUTTONDBLCLK then
    if Config_IsFileEnabled(GetCurrentPath()) then
      dim as integer x = cint(cshort(loword(lParam)))
      dim as integer y = cint(cshort(hiword(lParam)))
      if TryCopyResultAtClientPoint(hWnd, x, y) then return 0
    end if
  end if
  if oldSciProc <> 0 then
    return CallWindowProc(oldSciProc, hWnd, uMsg, wParam, lParam)
  end if
  return DefWindowProc(hWnd, uMsg, wParam, lParam)
end function

sub HookScintilla(byval hSci as HWND)
  dim as WNDPROC cur, prev
  if hSci = 0 then exit sub
  cur = cast(WNDPROC, GetWindowLongPtr(hSci, GWLP_WNDPROC))
  if cur = @SciSubclassProc then exit sub
  prev = cast(WNDPROC, SetWindowLongPtr(hSci, GWLP_WNDPROC, cast(LONG_PTR, @SciSubclassProc)))
  if oldSciProc = 0 then oldSciProc = prev
end sub

sub EnsureSciHooked()
  HookScintilla(nppData._scintillaMainHandle)
  HookScintilla(nppData._scintillaSecondHandle)
end sub

sub UnhookSci()
  if oldSciProc = 0 then exit sub
  if nppData._scintillaMainHandle <> 0 then
    if cast(WNDPROC, GetWindowLongPtr(nppData._scintillaMainHandle, GWLP_WNDPROC)) = @SciSubclassProc then
      SetWindowLongPtr(nppData._scintillaMainHandle, GWLP_WNDPROC, cast(LONG_PTR, oldSciProc))
    end if
  end if
  if nppData._scintillaSecondHandle <> 0 then
    if cast(WNDPROC, GetWindowLongPtr(nppData._scintillaSecondHandle, GWLP_WNDPROC)) = @SciSubclassProc then
      SetWindowLongPtr(nppData._scintillaSecondHandle, GWLP_WNDPROC, cast(LONG_PTR, oldSciProc))
    end if
  end if
  oldSciProc = 0
end sub

function CopyTextToClipboard(byref sText as string) as boolean
  dim as integer cch, cbBytes
  dim as HGLOBAL hMem
  dim as wstring ptr pMem
  if Len(sText) = 0 then return FALSE
  if OpenClipboard(nppData._nppHandle) = FALSE then return FALSE
  EmptyClipboard()

  cch = MultiByteToWideChar(CP_UTF8, 0, strptr(sText), Len(sText), 0, 0)
  if cch <= 0 then
    CloseClipboard()
    return FALSE
  end if
  cbBytes = (cch + 1) * sizeof(wstring)
  hMem = GlobalAlloc(GMEM_MOVEABLE, cbBytes)
  if hMem = 0 then
    CloseClipboard()
    return FALSE
  end if
  pMem = cast(wstring ptr, GlobalLock(hMem))
  if pMem = 0 then
    GlobalFree(hMem)
    CloseClipboard()
    return FALSE
  end if
  MultiByteToWideChar(CP_UTF8, 0, strptr(sText), Len(sText), pMem, cch)
  pMem[cch] = 0
  GlobalUnlock(hMem)
  if SetClipboardData(CF_UNICODETEXT, hMem) = 0 then
    GlobalFree(hMem)
    CloseClipboard()
    return FALSE
  end if
  CloseClipboard()
  return TRUE
end function

sub EnsureErrorAnnotationStyle(byval hScintilla as HWND)
  dim as integer styleOffset, badFore
  if hScintilla = 0 then exit sub
  styleOffset = SendMessage(hScintilla, SCI_EOLANNOTATIONGETSTYLEOFFSET, 0, 0)
  if styleOffset = 0 then
    styleOffset = SendMessage(hScintilla, SCI_ALLOCATEEXTENDEDSTYLES, 2, 0)
    if styleOffset > 0 then
      SendMessage(hScintilla, SCI_EOLANNOTATIONSETSTYLEOFFSET, styleOffset, 0)
    end if
  end if
  if styleOffset > 0 then
    badFore = SendMessage(hScintilla, SCI_STYLEGETFORE, STYLE_BRACEBAD, 0)
    SendMessage(hScintilla, SCI_STYLESETFORE, styleOffset + ANN_STYLE_ERROR, badFore)
  end if
end sub

function AnnotationStyleForText(byref sText as string) as integer
  dim as string sErr
  if Left(sText, Len(SMARTMATH_ERROR_PREFIX)) <> SMARTMATH_ERROR_PREFIX then return ANN_STYLE_DEFAULT
  sErr = Mid(sText, Len(SMARTMATH_ERROR_PREFIX) + 1)
  if Parser_IsFunctionHintError(sErr) then return ANN_STYLE_DEFAULT
  return ANN_STYLE_ERROR
end function

function CopyResultForLine(byval hScintilla as HWND, byval lineIdx as integer) as boolean
  dim as string sRes, sCopy
  if (lineIdx >= 0) andalso (lineIdx <= ubound(g_annText)) then
    sRes = g_annText(lineIdx)
  end if
  if Len(Trim(sRes)) = 0 then sRes = GetEolAnnotationText(hScintilla, lineIdx)
  if Len(Trim(sRes)) = 0 then return FALSE
  sCopy = NormalizeCopiedResult(sRes)
  if Len(sCopy) = 0 then return FALSE
  return CopyTextToClipboard(sCopy)
end function

sub SetLineAnnotation(byval hScintilla as HWND, byval lineIdx as integer, byval padding as integer, byref sText as string)
  dim as string sResText = space(padding) & sText
  dim as integer annStyle = AnnotationStyleForText(sText)
  if (lineIdx >= 0) andalso (lineIdx <= ubound(g_annText)) then
    if g_annText(lineIdx) <> sResText then
      g_annText(lineIdx) = sResText
      SendMessage(hScintilla, SCI_EOLANNOTATIONSETTEXT, lineIdx, cast(LPARAM, strptr(sResText)))
    end if
  else
    SendMessage(hScintilla, SCI_EOLANNOTATIONSETTEXT, lineIdx, cast(LPARAM, strptr(sResText)))
  end if
  if (annStyle = ANN_STYLE_ERROR) andalso _
     (SendMessage(hScintilla, SCI_EOLANNOTATIONGETSTYLEOFFSET, 0, 0) = 0) then
    annStyle = ANN_STYLE_DEFAULT
  end if
  SendMessage(hScintilla, SCI_EOLANNOTATIONSETSTYLE, lineIdx, annStyle)
end sub

sub ClearLineAnnotation(byval hScintilla as HWND, byval lineIdx as integer)
  if (lineIdx >= 0) andalso (lineIdx <= ubound(g_annText)) then
    if Len(g_annText(lineIdx)) = 0 then exit sub
    g_annText(lineIdx) = ""
  end if
  SendMessage(hScintilla, SCI_EOLANNOTATIONSETTEXT, lineIdx, 0)
end sub

sub InvalidateAnnotationCache()
  g_cacheReady = FALSE
  g_cachePath = ""
end sub

sub UpdateAnnotations(byval forceFull as boolean = FALSE)
  dim as string curPath = GetCurrentPath()
  if Config_IsFileEnabled(curPath) = FALSE then exit sub

  dim as HWND hScintilla = GetCurrentScintilla()
  dim as integer i, nLines, oldMask, oldCount, firstChanged
  dim as integer maxContentLen = 0, padding = 0
  dim as integer iStart, iEnd
  dim as RawResult raw
  
  if hScintilla = 0 then exit sub
  EnsureErrorAnnotationStyle(hScintilla)

  nLines = SendMessage(hScintilla, SCI_GETLINECOUNT, 0, 0)
  if nLines < 1 then nLines = 1

  redim curLines(0 to nLines - 1) as string
  redim curLens(0 to nLines - 1) as integer
  for i = 0 to nLines - 1
    iStart = SendMessage(hScintilla, SCI_POSITIONFROMLINE, i, 0)
    iEnd = SendMessage(hScintilla, SCI_GETLINEENDPOSITION, i, 0)
    curLens(i) = iEnd - iStart
    if curLens(i) > maxContentLen then maxContentLen = curLens(i)
    curLines(i) = GetScintillaLineText(hScintilla, i)
  next i

  oldCount = 0
  if g_cacheReady andalso (g_cachePath = curPath) then oldCount = ubound(g_cachedLineText) + 1
  firstChanged = 0
  if (forceFull = FALSE) andalso (oldCount = nLines) then
    firstChanged = -1
    for i = 0 to nLines - 1
      if curLines(i) <> g_cachedLineText(i) then
        firstChanged = i
        exit for
      end if
    next i
    if firstChanged < 0 then exit sub
  end if

  oldMask = SendMessage(hScintilla, SCI_GETMODEVENTMASK, 0, 0)
  SendMessage(hScintilla, SCI_SETMODEVENTMASK, 0, 0)
  SendMessage(hScintilla, SCI_EOLANNOTATIONSETVISIBLE, EOLANNOTATION_STANDARD, 0)

  Parser_ClearVariables()
  Parser_SetSupportComplexNumbers(Config_GetSupportComplexNumbers())

  redim preserve g_cachedLineText(0 to nLines - 1)
  redim preserve g_cachedResult(0 to nLines - 1)
  redim preserve g_annText(0 to nLines - 1)

  for i = 0 to nLines - 1
    if i < firstChanged then
      Parser_TryEvaluateExRaw(curLines(i), raw)
    else
      g_cachedResult(i) = DisplayTextFromEval(curLines(i))
    end if
    g_cachedLineText(i) = curLines(i)

    if Len(g_cachedResult(i)) > 0 then
      padding = maxContentLen - curLens(i) + 5
      SetLineAnnotation(hScintilla, i, padding, g_cachedResult(i))
    else
      ClearLineAnnotation(hScintilla, i)
    end if
  next i

  g_cacheReady = TRUE
  g_cachePath = curPath
  SendMessage(hScintilla, SCI_SETMODEVENTMASK, oldMask, 0)
end sub

sub UpdateUIState()
  dim as string curPath = GetCurrentPath()
  dim as boolean isEnabled = Config_IsFileEnabled(curPath)
  
  SendMessage(nppData._nppHandle, NPPM_SETMENUITEMCHECK, funcItems(0)._cmdID, iif(isEnabled, 1, 0))
  
  if isEnabled then
    UpdateAnnotations()
  else
    dim as HWND hScintilla = GetCurrentScintilla()
    if hScintilla <> 0 then
      SendMessage(hScintilla, SCI_EOLANNOTATIONCLEARALL, 0, 0)
      SendMessage(hScintilla, SCI_EOLANNOTATIONSETVISIBLE, EOLANNOTATION_HIDDEN, 0)
    end if
    InvalidateAnnotationCache()
  end if
end sub

sub TogglePlugin cdecl()
  dim as string curPath = GetCurrentPath()
  Config_ToggleFile(curPath)
  Config_Save()
  UpdateUIState()
end sub

sub SetPrecision(p as integer)
  Config_SetDecimalPlaces(p)
  dim as integer i
  for i = 0 to 8
    SendMessage(nppData._nppHandle, NPPM_SETMENUITEMCHECK, funcItems(IDX_PREC0 + i)._cmdID, 0)
  next i
  SendMessage(nppData._nppHandle, NPPM_SETMENUITEMCHECK, funcItems(IDX_PREC0 + p)._cmdID, 1)
  
  Config_Save()
  if Config_IsFileEnabled(GetCurrentPath()) then UpdateAnnotations(TRUE)
end sub

sub SetPrec0 cdecl() : SetPrecision(0) : end sub
sub SetPrec1 cdecl() : SetPrecision(1) : end sub
sub SetPrec2 cdecl() : SetPrecision(2) : end sub
sub SetPrec3 cdecl() : SetPrecision(3) : end sub
sub SetPrec4 cdecl() : SetPrecision(4) : end sub
sub SetPrec5 cdecl() : SetPrecision(5) : end sub
sub SetPrec6 cdecl() : SetPrecision(6) : end sub
sub SetPrec7 cdecl() : SetPrecision(7) : end sub
sub SetPrec8 cdecl() : SetPrecision(8) : end sub

sub ToggleComplexNumbers cdecl()
  dim as boolean enabled = not Config_GetSupportComplexNumbers()
  Config_SetSupportComplexNumbers(enabled)
  Config_Save()
  SendMessage(nppData._nppHandle, NPPM_SETMENUITEMCHECK, funcItems(IDX_COMPLEX)._cmdID, iif(enabled, 1, 0))
  if Config_IsFileEnabled(GetCurrentPath()) then UpdateAnnotations(TRUE)
end sub

sub ToggleShowErrors cdecl()
  dim as boolean enabled = not Config_GetShowErrors()
  Config_SetShowErrors(enabled)
  Config_Save()
  SendMessage(nppData._nppHandle, NPPM_SETMENUITEMCHECK, funcItems(IDX_SHOWERRORS)._cmdID, iif(enabled, 1, 0))
  if Config_IsFileEnabled(GetCurrentPath()) then UpdateAnnotations(TRUE)
end sub

extern "C"

sub setInfo(byval notpadPlusData as NppData) export
  nppData = notpadPlusData
end sub

function getName() as const wstring ptr export
  return @PLUGIN_NAME
end function

function getFuncsArray(byval nbF as integer ptr) as FuncItem ptr export
  *nbF = NB_FUNC
  dim as wstring * 64 sMainName = "Smart Math Plugin"
  
  with funcItems(IDX_TOGGLE)
    ._itemName = sMainName
    ._pFunc = @TogglePlugin
    ._cmdID = 0
    ._init2Check = FALSE
    ._pShKey = NULL
  end with

  with funcItems(IDX_SEPARATOR)
    ._itemName = ""
    ._pFunc = NULL
    ._cmdID = 0
    ._init2Check = FALSE
    ._pShKey = NULL
  end with
  
  static as PFUNCPLUGINCMD pFuncs(8) => { _
    @SetPrec0, @SetPrec1, @SetPrec2, @SetPrec3, @SetPrec4, _
    @SetPrec5, @SetPrec6, @SetPrec7, @SetPrec8 }
  
  dim as integer i
  dim as wstring * 64 sTempName
  for i = 0 to 8
    sTempName = "Decimal places " & i
    with funcItems(IDX_PREC0 + i)
      ._itemName = sTempName
      ._pFunc = pFuncs(i)
      ._cmdID = 0
      ._init2Check = FALSE
      ._pShKey = NULL
    end with
  next i

  with funcItems(IDX_COMPLEX)
    ._itemName = "Complex Numbers"
    ._pFunc = @ToggleComplexNumbers
    ._cmdID = 0
    ._init2Check = FALSE
    ._pShKey = NULL
  end with

  with funcItems(IDX_SHOWERRORS)
    ._itemName = "Show Errors"
    ._pFunc = @ToggleShowErrors
    ._cmdID = 0
    ._init2Check = FALSE
    ._pShKey = NULL
  end with
  return @funcItems(0)
end function

sub beNotified(byval pNotify as SCNotification ptr) export
  if pNotify->nmhdr.code = NPPN_READY then
    Config_Init(nppData._nppHandle)
    Config_Load()
    OrganizeMenu()
    EnsureSciHooked()
    SendMessage(nppData._nppHandle, NPPM_ADDSCNMODIFIEDFLAGS, 0, SC_MOD_TEXT_FLAGS)
    UpdateUIState()
    
  elseif pNotify->nmhdr.code = NPPN_TBMODIFICATION then
    dim as HDC hdc = GetDC(NULL)
    dim as integer bmpX = 16, bmpY = 16
    dim as integer icoX = 32, icoY = 32
    
    if hdc then
      bmpX = MulDiv(16, GetDeviceCaps(hdc, LOGPIXELSX), 96)
      bmpY = MulDiv(16, GetDeviceCaps(hdc, LOGPIXELSY), 96)
      icoX = MulDiv(32, GetDeviceCaps(hdc, LOGPIXELSX), 96)
      icoY = MulDiv(32, GetDeviceCaps(hdc, LOGPIXELSY), 96)
      ReleaseDC(NULL, hdc)
    end if
    
    dim as HBITMAP hBmp = LoadImage(hInst, MAKEINTRESOURCE(TB_BMP_ID), IMAGE_BITMAP, bmpX, bmpY, LR_LOADTRANSPARENT or LR_LOADMAP3DCOLORS)
    dim as HICON hIconLight = LoadImage(hInst, MAKEINTRESOURCE(TB_ICON_LIGHT_ID), IMAGE_ICON, icoX, icoY, LR_DEFAULTSIZE)
    dim as HICON hIconDark = LoadImage(hInst, MAKEINTRESOURCE(TB_ICON_DARK_ID), IMAGE_ICON, icoX, icoY, LR_DEFAULTSIZE)
    
    if hIconDark = 0 then hIconDark = hIconLight
    
    dim as toolbarIconsWithDarkMode tbIcons
    tbIcons.hToolbarBmp = hBmp
    tbIcons.hToolbarIcon = hIconLight
    tbIcons.hToolbarIconDarkMode = hIconDark
    
    SendMessage(nppData._nppHandle, NPPM_ADDTOOLBARICON_FORDARKMODE, funcItems(0)._cmdID, cast(LPARAM, @tbIcons))
    
  elseif pNotify->nmhdr.code = NPPN_BUFFERACTIVATED then
    UpdateUIState()
    
  elseif pNotify->nmhdr.code = NPPN_WORDSTYLESUPDATED _
      orelse pNotify->nmhdr.code = NPPN_LANGCHANGED then
    if Config_IsFileEnabled(GetCurrentPath()) then
      dim as HWND hSciTheme = GetCurrentScintilla()
      if hSciTheme <> 0 then EnsureErrorAnnotationStyle(hSciTheme)
    end if
    
  elseif pNotify->nmhdr.code = SCN_MODIFIED then
    if (pNotify->modificationType and SC_MOD_TEXT_FLAGS) <> 0 then
      if Config_IsFileEnabled(GetCurrentPath()) then UpdateAnnotations()
    end if
    
  elseif pNotify->nmhdr.code = NPPN_BEFORESHUTDOWN _
      orelse pNotify->nmhdr.code = NPPN_SHUTDOWN then
    isNppClosing = TRUE
    UnhookSci()
    
  elseif pNotify->nmhdr.code = NPPN_FILEBEFORECLOSE then
    if isNppClosing = FALSE then
      dim as integer bufferID = pNotify->nmhdr.idFrom
      dim as wstring * MAX_PATH fullPath
      SendMessage(nppData._nppHandle, NPPM_GETFULLPATHFROMBUFFERID, bufferID, cast(LPARAM, @fullPath))
      Config_DisableFile(str(fullPath))
    end if
  end if
end sub

function messageProc(byval uMsg as UINT, byval wParam as WPARAM, byval lParam as LPARAM) as LRESULT export
  return TRUE
end function

function isUnicode() as WINBOOL export
  return TRUE
end function

end extern