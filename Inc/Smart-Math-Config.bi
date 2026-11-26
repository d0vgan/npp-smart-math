#ifndef __SMART_MATH_CONFIG_BI__
#define __SMART_MATH_CONFIG_BI__

#include "windows.bi"

' Inicializa el gestor con el Handle de NPP (necesario para buscar rutas)
declare sub Config_Init(hNpp as HWND)

' Carga y Guardado
declare sub Config_Load()
declare sub Config_Save()

' Getters y Setters de Propiedades
declare sub Config_SetDecimalPlaces(p as Integer)
declare function Config_GetDecimalPlaces() as Integer
declare sub Config_SetUseThousandsSep(byval enabled as Boolean)
declare function Config_GetUseThousandsSep() as Boolean
declare sub Config_SetSupportComplexNumbers(byval enabled as Boolean)
declare function Config_GetSupportComplexNumbers() as Boolean
declare sub Config_SetShowErrors(byval enabled as Boolean)
declare function Config_GetShowErrors() as Boolean
declare sub Config_SetSyntaxHighlight(byval enabled as Boolean)
declare function Config_GetSyntaxHighlight() as Boolean
' Getters
declare function Config_GetDecimalSep() as String
declare function Config_GetThousandsSep() as String
declare function Config_GetArrayOutputSep() as String

' Gestion de Archivos Habilitados
declare function Config_IsFileEnabled(path as String) as Boolean
declare function Config_ToggleFile(path as String) as Boolean
' NUEVO: Funcion para forzar la desactivacion de un archivo (usado al cerrar pestaña)
declare sub Config_DisableFile(path as String)

#endif