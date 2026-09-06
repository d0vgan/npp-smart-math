@echo off
fbc -dll -gen gcc "Smart-Math.bas" "Smart-Math-Format.bas" "Smart-Math-CopyNormalize.bas" "MathParser.bas" "ConfigManager.bas" "Res\Resource.rc" -x "SmartMath.dll"
pause