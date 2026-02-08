@echo off
fbc -dll -gen gcc "Smart-Math.bas" "MathParser.bas" "ConfigManager.bas" "Res\Resource.rc"
pause