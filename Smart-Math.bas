#include "windows.bi"
#include "crt.bi"
#include "Inc\PluginInterface.bi"
#include "Inc\MathParser.bi"
#include "Inc\ConfigManager.bi"

const PLUGIN_NAME = wstr("Smart Math Plugin")
const TB_ICON_ID = 100
const NB_FUNC = 10
const SCI_GETLINECOUNT = 2154
const SCI_GETLINE = 2153
const SCI_LINELENGTH = 2350
const SCI_POSITIONFROMLINE = 2167
const SCI_GETLINEENDPOSITION = 2136
const SCI_EOLANNOTATIONSETTEXT = 2740
const SCI_EOLANNOTATIONSETVISIBLE = 2745
const SCI_EOLANNOTATIONCLEARALL = 2744
const SCI_GETMODEVENTMASK = 2378
const SCI_SETMODEVENTMASK = 2359
const EOLANNOTATION_STANDARD = 1
const EOLANNOTATION_HIDDEN = 0
const SCN_MODIFIED = 2008
const NPPM_GETFULLPATHFROMBUFFERID = (NPPMSG + 58)
const NPPM_GETCURRENTBUFFERID = (NPPMSG + 60)

dim shared as HINSTANCE hInst
dim shared as NppData nppData
dim shared as FuncItem funcItems(NB_FUNC - 1)
dim shared as boolean isNppClosing = FALSE

declare sub UpdateAnnotations()
declare sub SetPrecision(p as integer)

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
  
  for i = 1 to 9
    RemoveMenu(hMyMenu, funcItems(i)._cmdID, MF_BYCOMMAND)
    AppendMenu(hSubMenuDecimal, MF_STRING, funcItems(i)._cmdID, wstr(str(i - 1)))
  next i
  
  AppendMenu(hMyMenu, MF_STRING or MF_POPUP, cast(UINT_PTR, hSubMenuDecimal), wstr("Decimal Places"))
  DrawMenuBar(nppData._nppHandle)
  SetPrecision(Config_GetDecimalPlaces())
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

sub UpdateAnnotations()
  if Config_IsFileEnabled(GetCurrentPath()) = FALSE then exit sub

  dim as HWND hScintilla = GetCurrentScintilla()
  dim as integer i, nLines, oldMask, lineBufLen, lineContentLen
  dim as integer maxContentLen = 0, padding = 0
  dim as integer iStart, iEnd
  dim as double dRes
  dim as zstring ptr pLineBuf
  dim as string sResText
  dim as zstring * 64 sFormatBuf
  dim as integer decPlaces = Config_GetDecimalPlaces()
  
  if hScintilla = 0 then exit sub

  oldMask = SendMessage(hScintilla, SCI_GETMODEVENTMASK, 0, 0)
  SendMessage(hScintilla, SCI_SETMODEVENTMASK, 0, 0)
  SendMessage(hScintilla, SCI_EOLANNOTATIONCLEARALL, 0, 0)
  SendMessage(hScintilla, SCI_EOLANNOTATIONSETVISIBLE, EOLANNOTATION_STANDARD, 0)
  
  Parser_ClearVariables()

  nLines = SendMessage(hScintilla, SCI_GETLINECOUNT, 0, 0)
  
  for i = 0 to nLines - 1
    iStart = SendMessage(hScintilla, SCI_POSITIONFROMLINE, i, 0)
    iEnd = SendMessage(hScintilla, SCI_GETLINEENDPOSITION, i, 0)
    lineContentLen = iEnd - iStart
    if lineContentLen > maxContentLen then maxContentLen = lineContentLen
  next i

  for i = 0 to nLines - 1
    lineBufLen = SendMessage(hScintilla, SCI_LINELENGTH, i, 0)
    iStart = SendMessage(hScintilla, SCI_POSITIONFROMLINE, i, 0)
    iEnd = SendMessage(hScintilla, SCI_GETLINEENDPOSITION, i, 0)
    lineContentLen = iEnd - iStart

    if lineBufLen > 0 then
      pLineBuf = callocate(lineBufLen + 1)
      SendMessage(hScintilla, SCI_GETLINE, i, cast(LPARAM, pLineBuf))
      pLineBuf[lineBufLen] = 0
      
      if Parser_TryEvaluate(pLineBuf, dRes) then
        padding = maxContentLen - lineContentLen + 5
        sprintf(sFormatBuf, "%.*f", decPlaces, dRes)
        sResText = space(padding) & "= " & *cast(zstring ptr, @sFormatBuf)
        SendMessage(hScintilla, SCI_EOLANNOTATIONSETTEXT, i, cast(LPARAM, strptr(sResText)))
      end if
      deallocate(pLineBuf)
    end if
  next i
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
  for i = 1 to 9
    SendMessage(nppData._nppHandle, NPPM_SETMENUITEMCHECK, funcItems(i)._cmdID, 0)
  next i
  SendMessage(nppData._nppHandle, NPPM_SETMENUITEMCHECK, funcItems(p + 1)._cmdID, 1)
  
  Config_Save()
  if Config_IsFileEnabled(GetCurrentPath()) then UpdateAnnotations()
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
  
  with funcItems(0)
    ._itemName = sMainName
    ._pFunc = @TogglePlugin
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
    with funcItems(i + 1)
      ._itemName = sTempName
      ._pFunc = pFuncs(i)
      ._cmdID = 0
      ._init2Check = FALSE
      ._pShKey = NULL
    end with
  next i
  return @funcItems(0)
end function

sub beNotified(byval pNotify as SCNotification ptr) export
  if pNotify->nmhdr.code = NPPN_READY then
    Config_Init(nppData._nppHandle)
    Config_Load()
    OrganizeMenu()
    UpdateUIState()
    
  elseif pNotify->nmhdr.code = NPPN_TBMODIFICATION then
    dim as HBITMAP hBmp = CreateCompatibleBitmap(GetDC(nppData._nppHandle), 16, 16)
    dim as HICON hIcon = LoadImage(hInst, MAKEINTRESOURCE(TB_ICON_ID), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR)
    dim as ToolbarIcons tbIcons
    tbIcons.hToolbarBmp = hBmp
    tbIcons.hToolbarIcon = hIcon
    SendMessage(nppData._nppHandle, NPPM_ADDTOOLBARICON, funcItems(0)._cmdID, cast(LPARAM, @tbIcons))
    
  elseif pNotify->nmhdr.code = NPPN_BUFFERACTIVATED then
    UpdateUIState()
    
  elseif pNotify->nmhdr.code = SCN_MODIFIED then
    if Config_IsFileEnabled(GetCurrentPath()) then UpdateAnnotations()
    
  elseif pNotify->nmhdr.code = NPPN_BEFORESHUTDOWN then
    isNppClosing = TRUE
    
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