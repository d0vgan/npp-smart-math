@echo off
echo Compiling...
fbc -dll -gen gcc "Smart-Math.bas" "Smart-Math-Format.bas" "Smart-Math-CopyNormalize.bas" "Smart-Math-About.bas" "MathParser.bas" "Smart-Math-Config.bas" "Res\Resource.rc" -x "SmartMath.dll"
pause