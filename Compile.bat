@echo off
fbc -dll -gen gcc "Smart-Math.bas" "Smart-Math-Format.bas" "MathParser.bas" "ConfigManager.bas" "Res\Resource.rc"
pause