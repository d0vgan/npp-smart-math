#ifndef CONFIGMANAGER_H
#define CONFIGMANAGER_H

#include "windows.bi"

' Inicializa el gestor con el Handle de NPP (necesario para buscar rutas)
declare sub Config_Init(hNpp as HWND)

' Carga y Guardado
declare sub Config_Load()
declare sub Config_Save()

' Getters y Setters de Propiedades
declare sub Config_SetDecimalPlaces(p as integer)
declare function Config_GetDecimalPlaces() as integer
declare sub Config_SetSupportComplexNumbers(byval enabled as boolean)
declare function Config_GetSupportComplexNumbers() as boolean

' Gestion de Archivos Habilitados
declare function Config_IsFileEnabled(path as string) as boolean
declare sub Config_ToggleFile(path as string)
' NUEVO: Funcion para forzar la desactivacion de un archivo (usado al cerrar pestaña)
declare sub Config_DisableFile(path as string)

#endif