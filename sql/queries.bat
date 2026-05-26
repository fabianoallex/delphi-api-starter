@echo off
"C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\brcc32.exe" queries.rc
if %errorlevel% == 0 (
    echo queries.res atualizado com sucesso.
) else (
    echo ERRO ao compilar queries.rc
)
pause
