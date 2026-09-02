@echo off
REM =====================================================================
REM sim.bat -- Compila y corre los testbenches, y genera el bitstream
REM
REM Abrir primero la consola de OSS CAD Suite con start.bat, navegar
REM hasta esta carpeta y ejecutar:
REM
REM   sim.bat            corre todos los testbenches rapidos
REM
REM   sim.bat adder4     sumador de 4 bits         512 casos
REM   sim.bat shifter    barrel shifters            64 casos
REM   sim.bat opsel      contador de operacion
REM   sim.bat alu        ALU completa             2048 casos
REM   sim.bat display    cadena de display         107 casos
REM   sim.bat debounce   debounce y prescaler       11 casos
REM   sim.bat control    contadores, registro, FSM  79 casos
REM   sim.bat calc       envoltorio calculadora_4bits  17 casos
REM   sim.bat top        calculadora completa       33 casos  (LENTO)
REM
REM   El testbench de la catedra NO tiene target propio: te lo pasan el
REM   dia de la evaluacion y no se sabe como se va a llamar. Se corre a
REM   mano, ver el README (seccion "Testbench de la catedra").
REM
REM   sim.bat demo       casos de la evaluacion  -> editar tb/demo_tb.v
REM   sim.bat wave       onda curada de la ALU
REM
REM   sim.bat fpga       sintesis + place and route + bitstream
REM   sim.bat prog       programa la placa
REM   sim.bat clean      borra los archivos de simulacion
REM   sim.bat distclean  borra tambien el bitstream (calc.json/asc/bin)
REM
REM DETECCION DE FALLOS
REM   vvp termina con codigo 0 aunque el testbench imprima HAY FALLAS,
REM   asi que mirar el errorlevel de vvp no sirve. Este script busca esa
REM   cadena en la salida de cada testbench y lleva la cuenta en FALLOS.
REM   Al final imprime el resumen y sale con ese numero como errorlevel,
REM   asi que un 'sim.bat' que termina en 0 significa que TODO paso.
REM
REM Nota: en Windows NI iverilog NI yosys expanden comodines, y cmd.exe
REM tampoco. Por eso los archivos van listados uno por uno. La lista
REM completa de src/ esta en la variable SRC, definida una sola vez mas
REM abajo: si agregas un modulo nuevo, se agrega AHI y nada mas.
REM
REM Ondas:  gtkwave demo.vcd tb/demo.gtkw
REM         gtkwave alu_wave.vcd tb/alu_wave.gtkw
REM =====================================================================

setlocal

set FALLOS=0
set TMPOUT=%TEMP%\simbat_%RANDOM%.txt

REM ---------------------------------------------------------------------
REM Lista unica de fuentes. La usan run_top y run_fpga.
REM ---------------------------------------------------------------------
set SRC=src/abs4.v src/adder4.v src/alu.v src/counter4.v src/dash_s0.v
set SRC=%SRC% src/debounce.v src/display_chain.v src/display_src.v
set SRC=%SRC% src/fsm_control.v src/full_adder.v src/mux2.v
set SRC=%SRC% src/op_decoder.v src/op_selector.v src/prescaler.v
set SRC=%SRC% src/seg7_decoder.v src/shift_left.v src/shift_right.v
set SRC=%SRC% src/top.v

REM calculadora_4bits.v NO va en SRC a proposito: es el envoltorio de la
REM evaluacion, no cuelga de 'top' y no forma parte del diseno de la placa.
REM Si se lo pasa a yosys, cambia el orden de las celdas y sale un
REM bitstream distinto (mismo circuito, otro placement) sin ninguna
REM ventaja. Se compila aparte, en run_calc.

REM Nucleo de la ALU: lo que necesita el envoltorio de la evaluacion.
set ALUSRC=src/mux2.v src/full_adder.v src/adder4.v src/shift_left.v
set ALUSRC=%ALUSRC% src/shift_right.v src/op_decoder.v src/alu.v

set TARGET=%1
if "%TARGET%"=="" set TARGET=all

if "%TARGET%"=="all"       goto t_all
if "%TARGET%"=="adder4"    goto t_adder4
if "%TARGET%"=="shifter"   goto t_shifter
if "%TARGET%"=="opsel"     goto t_opsel
if "%TARGET%"=="alu"       goto t_alu
if "%TARGET%"=="display"   goto t_display
if "%TARGET%"=="debounce"  goto t_debounce
if "%TARGET%"=="control"   goto t_control
if "%TARGET%"=="calc"      goto t_calc
if "%TARGET%"=="top"       goto t_top
if "%TARGET%"=="demo"      goto t_demo
if "%TARGET%"=="wave"      goto t_wave
if "%TARGET%"=="fpga"      goto t_fpga
if "%TARGET%"=="prog"      goto t_prog
if "%TARGET%"=="clean"     goto t_clean
if "%TARGET%"=="distclean" goto t_distclean

echo.
echo Objetivo desconocido: %TARGET%
echo Opciones: all adder4 shifter opsel alu display debounce control
echo           calc top demo wave fpga prog clean distclean
set FALLOS=1
goto fin


REM ---------------------------------------------------------------------
REM Conjuntos
REM ---------------------------------------------------------------------
:t_all
call :run_adder4
call :run_shifter
call :run_opsel
call :run_alu
call :run_display
call :run_debounce
call :run_control
call :run_calc
echo.
echo =====================================================================
call :resumen
echo Falta 'sim.bat top' (lento, 2-3 min) y 'sim.bat fpga'.
echo =====================================================================
goto fin

:t_adder4
call :run_adder4
goto fin

:t_shifter
call :run_shifter
goto fin

:t_opsel
call :run_opsel
goto fin

:t_alu
call :run_alu
goto fin

:t_display
call :run_display
goto fin

:t_debounce
call :run_debounce
goto fin

:t_control
call :run_control
goto fin

:t_calc
call :run_calc
goto fin

:t_top
call :run_top
goto fin

:t_demo
call :run_demo
goto fin

:t_wave
call :run_wave
goto fin

:t_fpga
call :run_fpga
goto fin

:t_prog
call :run_prog
goto fin

:t_clean
call :borra_sim
echo Listo. El bitstream (calc.bin) NO se toco: para borrarlo, sim.bat distclean
goto fin

:t_distclean
call :borra_sim
echo Borrando el bitstream...
if exist calc.json del /q calc.json
if exist calc.asc  del /q calc.asc
if exist calc.bin  del /q calc.bin
echo Listo.
goto fin


REM =====================================================================
REM Ayudantes
REM =====================================================================

REM ---------------------------------------------------------------------
REM corre -- ejecuta un testbench ya compilado y cuenta si fallo
REM   %1 = ejecutable   %2 = nombre para el mensaje   %3 = flags de vvp
REM ---------------------------------------------------------------------
:corre
vvp %3 %1 > "%TMPOUT%" 2>&1
type "%TMPOUT%"
findstr /C:"HAY FALLAS" "%TMPOUT%" >nul
if not errorlevel 1 (
    echo.
    echo   *** %2: el testbench reporto errores ***
    set /a FALLOS+=1
)
exit /b 0

REM ---------------------------------------------------------------------
REM no_compila -- mensaje y conteo cuando iverilog falla
REM ---------------------------------------------------------------------
:no_compila
echo.
echo   *** %~1: no compila ***
set /a FALLOS+=1
exit /b 1

REM ---------------------------------------------------------------------
REM resumen -- veredicto global
REM ---------------------------------------------------------------------
:resumen
if "%FALLOS%"=="0" (
    echo   TODO OK -- ningun testbench reporto errores
) else (
    echo   *** %FALLOS% testbench con problemas -- revisar arriba ***
)
exit /b 0

REM ---------------------------------------------------------------------
REM borra_sim -- ejecutables de iverilog y ondas. NO toca el bitstream.
REM ---------------------------------------------------------------------
:borra_sim
echo.
echo Borrando archivos de simulacion...
if exist sim_adder4*   del /q sim_adder4*
if exist sim_shifter*  del /q sim_shifter*
if exist sim_opsel*    del /q sim_opsel*
if exist sim_alu*      del /q sim_alu*
if exist sim_display*  del /q sim_display*
if exist sim_debounce* del /q sim_debounce*
if exist sim_control*  del /q sim_control*
if exist sim_calc*     del /q sim_calc*
if exist sim_top*      del /q sim_top*
if exist sim_demo*     del /q sim_demo*
if exist sim_wave*     del /q sim_wave*
if exist *.vcd         del /q *.vcd
exit /b 0


REM =====================================================================
REM Rutinas
REM =====================================================================

:run_adder4
echo.
echo --- adder4 ----------------------------------------------------------
iverilog -o sim_adder4 src/full_adder.v src/adder4.v tb/adder4_tb.v
if errorlevel 1 (
    call :no_compila adder4
    exit /b 1
)
call :corre sim_adder4 adder4
exit /b 0

:run_shifter
echo.
echo --- shifters --------------------------------------------------------
iverilog -o sim_shifter src/mux2.v src/shift_left.v src/shift_right.v tb/shifter_tb.v
if errorlevel 1 (
    call :no_compila shifters
    exit /b 1
)
call :corre sim_shifter shifters
exit /b 0

:run_opsel
echo.
echo --- op_selector -----------------------------------------------------
iverilog -o sim_opsel src/op_selector.v tb/op_selector_tb.v
if errorlevel 1 (
    call :no_compila op_selector
    exit /b 1
)
call :corre sim_opsel op_selector
exit /b 0

:run_alu
echo.
echo --- ALU -------------------------------------------------------------
iverilog -o sim_alu src/full_adder.v src/adder4.v src/mux2.v src/shift_left.v src/shift_right.v src/op_decoder.v src/alu.v tb/alu_tb.v
if errorlevel 1 (
    call :no_compila ALU
    exit /b 1
)
call :corre sim_alu ALU
exit /b 0

:run_display
echo.
echo --- cadena de display -----------------------------------------------
iverilog -o sim_display src/full_adder.v src/adder4.v src/mux2.v src/display_src.v src/abs4.v src/seg7_decoder.v src/display_chain.v tb/display_tb.v
if errorlevel 1 (
    call :no_compila display
    exit /b 1
)
call :corre sim_display display
exit /b 0

:run_debounce
echo.
echo --- debounce y prescaler --------------------------------------------
iverilog -o sim_debounce src/mux2.v src/prescaler.v src/debounce.v tb/debounce_tb.v
if errorlevel 1 (
    call :no_compila debounce
    exit /b 1
)
call :corre sim_debounce debounce
exit /b 0

:run_control
echo.
echo --- contadores, registro y FSM --------------------------------------
iverilog -o sim_control src/mux2.v src/counter4.v src/fsm_control.v tb/control_tb.v
if errorlevel 1 (
    call :no_compila control
    exit /b 1
)
call :corre sim_control control
exit /b 0

:run_calc
echo.
echo --- envoltorio de la evaluacion (calculadora_4bits) ------------------
iverilog -o sim_calc %ALUSRC% src/calculadora_4bits.v tb/calculadora_4bits_tb.v
if errorlevel 1 (
    call :no_compila calculadora_4bits
    exit /b 1
)
call :corre sim_calc calculadora_4bits
exit /b 0

:run_top
echo.
echo --- calculadora completa --------------------------------------------
echo Simula pulsaciones reales a traves del debounce. Tarda 2-3 minutos.
iverilog -o sim_top %SRC% tb/top_tb.v
if errorlevel 1 (
    call :no_compila top
    exit /b 1
)
call :corre sim_top top -N
exit /b 0

:run_demo
echo.
echo --- casos de la evaluacion ------------------------------------------
iverilog -o sim_demo src/full_adder.v src/adder4.v src/mux2.v src/shift_left.v src/shift_right.v src/op_decoder.v src/alu.v tb/demo_tb.v
if errorlevel 1 (
    call :no_compila demo
    exit /b 1
)
vvp sim_demo
echo.
echo Ver la onda con:  gtkwave demo.vcd tb/demo.gtkw
exit /b 0

:run_wave
echo.
echo --- onda curada de la ALU -------------------------------------------
iverilog -o sim_wave src/full_adder.v src/adder4.v src/mux2.v src/shift_left.v src/shift_right.v src/op_decoder.v src/alu.v tb/alu_wave_tb.v
if errorlevel 1 (
    call :no_compila wave
    exit /b 1
)
vvp sim_wave
echo.
echo Ver la onda con:  gtkwave alu_wave.vcd tb/alu_wave.gtkw
exit /b 0

:run_fpga
echo.
echo --- sintesis --------------------------------------------------------
yosys -p "read_verilog %SRC%; hierarchy -top top; synth_ice40 -json calc.json"
if errorlevel 1 (
    call :no_compila sintesis
    exit /b 1
)
echo.
echo --- place and route -------------------------------------------------
nextpnr-ice40 --hx1k --package vq100 --freq 25 --json calc.json --pcf go_board.pcf --asc calc.asc
if errorlevel 1 (
    call :no_compila "place and route"
    exit /b 1
)
echo.
echo --- bitstream -------------------------------------------------------
icepack calc.asc calc.bin
if errorlevel 1 (
    call :no_compila icepack
    exit /b 1
)
echo.
echo Bitstream listo: calc.bin
echo Para programar la placa:  sim.bat prog
exit /b 0

:run_prog
echo.
if not exist calc.bin (
    echo No existe calc.bin. Corre primero:  sim.bat fpga
    set /a FALLOS+=1
    exit /b 1
)
iceprog calc.bin
if errorlevel 1 (
    call :no_compila iceprog
    exit /b 1
)
exit /b 0


REM =====================================================================
REM Salida
REM =====================================================================

REM Con un solo objetivo el veredicto ya lo imprimio el propio testbench;
REM aca solo se limpia el temporal y se propaga el errorlevel.
:fin
if exist "%TMPOUT%" del /q "%TMPOUT%"
endlocal & exit /b %FALLOS%
