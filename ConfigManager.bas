#include "windows.bi"
#include "crt.bi"
#include "Inc\PluginInterface.bi"
#include "Inc\ConfigManager.bi"

const INI_FILENAME = wstr("\Smart-Math.ini")
const NPPM_GETPLUGINSCONFIGDIR = (WM_USER + 1000 + 46)

dim shared as wstring * MAX_PATH iniFilePath
dim shared as integer storedDecimalPlaces = 2
dim shared as boolean storedSupportComplexNumbers = FALSE
dim shared as boolean storedShowErrors = FALSE
dim shared as string enabledFiles()
dim shared as HWND hNppWnd

private sub PrepareIniPath()
  dim as wstring * MAX_PATH configDir
  SendMessage(hNppWnd, NPPM_GETPLUGINSCONFIGDIR, MAX_PATH, cast(LPARAM, @configDir))
  CreateDirectory(configDir, NULL)
  iniFilePath = configDir & INI_FILENAME
end sub

sub Config_Init(hNpp as HWND)
  hNppWnd = hNpp
  PrepareIniPath()
end sub

sub Config_SetDecimalPlaces(p as integer)
  if p < 0 then p = 0
  if p > 8 then p = 8
  storedDecimalPlaces = p
end sub

function Config_GetDecimalPlaces() as integer
  return storedDecimalPlaces
end function

sub Config_SetSupportComplexNumbers(byval enabled as boolean)
  storedSupportComplexNumbers = enabled
end sub

function Config_GetSupportComplexNumbers() as boolean
  return storedSupportComplexNumbers
end function

sub Config_SetShowErrors(byval enabled as boolean)
  storedShowErrors = enabled
end sub

function Config_GetShowErrors() as boolean
  return storedShowErrors
end function

function Config_IsFileEnabled(path as string) as boolean
  dim as integer i
  for i = lbound(enabledFiles) to ubound(enabledFiles)
    if enabledFiles(i) = path then return TRUE
  next i
  return FALSE
end function

sub Config_ToggleFile(path as string)
  dim as integer i, idx = -1
  
  for i = lbound(enabledFiles) to ubound(enabledFiles)
    if enabledFiles(i) = path then
      idx = i
      exit for
    end if
  next i
  
  if idx = -1 then
    if ubound(enabledFiles) = -1 then
      redim enabledFiles(0)
    else
      redim preserve enabledFiles(ubound(enabledFiles) + 1)
    end if
    enabledFiles(ubound(enabledFiles)) = path
  else
    if idx < ubound(enabledFiles) then
      enabledFiles(idx) = enabledFiles(ubound(enabledFiles))
    end if
    if ubound(enabledFiles) > 0 then
      redim preserve enabledFiles(ubound(enabledFiles) - 1)
    else
      erase enabledFiles
    end if
  end if
end sub

sub Config_DisableFile(path as string)
  dim as integer i, idx = -1
  
  for i = lbound(enabledFiles) to ubound(enabledFiles)
    if enabledFiles(i) = path then
      idx = i
      exit for
    end if
  next i
  
  if idx <> -1 then
    if idx < ubound(enabledFiles) then
      enabledFiles(idx) = enabledFiles(ubound(enabledFiles))
    end if
    
    if ubound(enabledFiles) > 0 then
      redim preserve enabledFiles(ubound(enabledFiles) - 1)
    else
      erase enabledFiles
    end if
    Config_Save()
  end if
end sub

sub Config_Save()
  dim as string allPaths = ""
  dim as integer i
  
  WritePrivateProfileString(wstr("Settings"), wstr("DecimalPlaces"), wstr(str(storedDecimalPlaces)), iniFilePath)
  WritePrivateProfileString(wstr("Settings"), wstr("ComplexNumbers"), wstr(iif(storedSupportComplexNumbers, "1", "0")), iniFilePath)
  WritePrivateProfileString(wstr("Settings"), wstr("ShowErrors"), wstr(iif(storedShowErrors, "1", "0")), iniFilePath)
  
  for i = lbound(enabledFiles) to ubound(enabledFiles)
    if len(enabledFiles(i)) > 0 then
      if len(allPaths) > 0 then allPaths &= "|"
      allPaths &= enabledFiles(i)
    end if
  next i
  
  WritePrivateProfileString(wstr("Settings"), wstr("ActiveTabs"), wstr(allPaths), iniFilePath)
end sub

sub Config_Load()
  storedDecimalPlaces = GetPrivateProfileInt(wstr("Settings"), wstr("DecimalPlaces"), 2, iniFilePath)
  if storedDecimalPlaces < 0 then storedDecimalPlaces = 0
  if storedDecimalPlaces > 8 then storedDecimalPlaces = 8
  storedSupportComplexNumbers = (GetPrivateProfileInt(wstr("Settings"), wstr("ComplexNumbers"), 0, iniFilePath) <> 0)
  storedShowErrors = (GetPrivateProfileInt(wstr("Settings"), wstr("ShowErrors"), 0, iniFilePath) <> 0)
  
  dim as zstring * 32768 buffer
  GetPrivateProfileString(wstr("Settings"), wstr("ActiveTabs"), wstr(""), @buffer, 32768, iniFilePath)
  
  erase enabledFiles
  
  dim as string sBuffer = buffer
  dim as integer pPipe, pStart = 1
  dim as string sPath
  
  if len(sBuffer) > 0 then
    do
      pPipe = instr(pStart, sBuffer, "|")
      if pPipe > 0 then
        sPath = mid(sBuffer, pStart, pPipe - pStart)
        pStart = pPipe + 1
      else
        sPath = mid(sBuffer, pStart)
      end if
      
      if len(sPath) > 0 then
        if ubound(enabledFiles) = -1 then
          redim enabledFiles(0)
        else
          redim preserve enabledFiles(ubound(enabledFiles) + 1)
        end if
        enabledFiles(ubound(enabledFiles)) = sPath
      end if
    loop while pPipe > 0
  end if
end sub