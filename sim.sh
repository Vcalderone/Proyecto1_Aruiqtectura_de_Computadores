#!/usr/bin/env bash
#=====================================================================
# sim.sh -- Equivalente en bash de sim.bat, para correr el proyecto
#           desde WSL/Linux (donde no sirve un .bat de Windows).
#
# Mismos objetivos y mismos comandos de iverilog que sim.bat, adaptados
# a bash. Requiere: iverilog, vvp, gtkwave, yosys, nextpnr-ice40,
# icepack, iceprog en el PATH (los trae OSS CAD Suite).
#
# Uso:
#   ./sim.sh            corre todos los testbenches rapidos
#   ./sim.sh adder4     sumador de 4 bits          512 casos
#   ./sim.sh shifter    barrel shifters             64 casos
#   ./sim.sh opsel      contador de operacion
#   ./sim.sh alu        ALU completa              2048 casos
#   ./sim.sh display    cadena de display          107 casos
#   ./sim.sh debounce   debounce y prescaler        11 casos
#   ./sim.sh control    contadores, registro, FSM   79 casos
#   ./sim.sh calc       envoltorio calculadora_4bits 17 casos
#   ./sim.sh top        calculadora completa        33 casos (lento)
#   ./sim.sh demo       casos de la evaluacion  -> editar tb/demo_tb.v
#   ./sim.sh wave       onda curada de la ALU
#   ./sim.sh fpga       sintesis + place&route + bitstream
#   ./sim.sh prog       programa la placa (iceprog)
#   ./sim.sh clean      borra archivos de simulacion
#   ./sim.sh distclean  borra tambien el bitstream
#
# Salida: exit code 0 solo si NINGUN testbench reporto errores.
#=====================================================================
set -u
cd "$(dirname "$0")"

FALLOS=0
TMPOUT="$(mktemp)"
trap 'rm -f "$TMPOUT"' EXIT

SRC="src/abs4.v src/adder4.v src/alu.v src/counter4.v src/dash_s0.v \
src/debounce.v src/display_chain.v src/display_src.v \
src/fsm_control.v src/full_adder.v src/mux2.v \
src/op_decoder.v src/op_selector.v src/prescaler.v \
src/seg7_decoder.v src/shift_left.v src/shift_right.v src/top.v"

ALUSRC="src/mux2.v src/full_adder.v src/adder4.v src/shift_left.v \
src/shift_right.v src/op_decoder.v src/alu.v"

corre() {   # $1 = ejecutable  $2 = nombre  $3.. = flags de vvp
    local exe="$1" nombre="$2"; shift 2
    vvp "$@" "$exe" > "$TMPOUT" 2>&1
    cat "$TMPOUT"
    if grep -q "HAY FALLAS" "$TMPOUT"; then
        echo; echo "  *** $nombre: el testbench reporto errores ***"
        FALLOS=$((FALLOS+1))
    fi
}

no_compila() {
    echo; echo "  *** $1: no compila ***"
    FALLOS=$((FALLOS+1))
}

run_adder4()   { echo; echo "--- adder4 ----------------------------------------------------------";
    iverilog -o sim_adder4 src/full_adder.v src/adder4.v tb/adder4_tb.v && corre sim_adder4 adder4 || no_compila adder4; }
run_shifter()  { echo; echo "--- shifters --------------------------------------------------------";
    iverilog -o sim_shifter src/mux2.v src/shift_left.v src/shift_right.v tb/shifter_tb.v && corre sim_shifter shifters || no_compila shifters; }
run_opsel()    { echo; echo "--- op_selector -----------------------------------------------------";
    iverilog -o sim_opsel src/op_selector.v tb/op_selector_tb.v && corre sim_opsel op_selector || no_compila op_selector; }
run_alu()      { echo; echo "--- ALU -------------------------------------------------------------";
    iverilog -o sim_alu src/full_adder.v src/adder4.v src/mux2.v src/shift_left.v src/shift_right.v src/op_decoder.v src/alu.v tb/alu_tb.v && corre sim_alu ALU || no_compila ALU; }
run_display()  { echo; echo "--- cadena de display -------------------------------------------------";
    iverilog -o sim_display src/full_adder.v src/adder4.v src/mux2.v src/display_src.v src/abs4.v src/seg7_decoder.v src/display_chain.v tb/display_tb.v && corre sim_display display || no_compila display; }
run_debounce() { echo; echo "--- debounce y prescaler ----------------------------------------------";
    iverilog -o sim_debounce src/mux2.v src/prescaler.v src/debounce.v tb/debounce_tb.v && corre sim_debounce debounce || no_compila debounce; }
run_control()  { echo; echo "--- contadores, registro y FSM -----------------------------------------";
    iverilog -o sim_control src/mux2.v src/counter4.v src/fsm_control.v tb/control_tb.v && corre sim_control control || no_compila control; }
run_calc()     { echo; echo "--- envoltorio de la evaluacion (calculadora_4bits) --------------------";
    iverilog -o sim_calc $ALUSRC src/calculadora_4bits.v tb/calculadora_4bits_tb.v && corre sim_calc calculadora_4bits || no_compila calculadora_4bits; }
run_top()      { echo; echo "--- calculadora completa (lento, 2-3 min) ------------------------------";
    iverilog -o sim_top $SRC tb/top_tb.v && corre sim_top top -N || no_compila top; }
run_demo()     { echo; echo "--- casos de la evaluacion ----------------------------------------------";
    iverilog -o sim_demo src/full_adder.v src/adder4.v src/mux2.v src/shift_left.v src/shift_right.v src/op_decoder.v src/alu.v tb/demo_tb.v \
      && { vvp sim_demo; echo; echo "Ver la onda con:  gtkwave demo.vcd tb/demo.gtkw"; } || no_compila demo; }
run_wave()     { echo; echo "--- onda curada de la ALU -----------------------------------------------";
    iverilog -o sim_wave src/full_adder.v src/adder4.v src/mux2.v src/shift_left.v src/shift_right.v src/op_decoder.v src/alu.v tb/alu_wave_tb.v \
      && { vvp sim_wave; echo; echo "Ver la onda con:  gtkwave alu_wave.vcd tb/alu_wave.gtkw"; } || no_compila wave; }

run_fpga() {
    echo; echo "--- sintesis ----------------------------------------------------------"
    yosys -p "read_verilog $SRC; hierarchy -top top; synth_ice40 -json calc.json" || { no_compila sintesis; return 1; }
    echo; echo "--- place and route -----------------------------------------------------"
    nextpnr-ice40 --hx1k --package vq100 --freq 25 --json calc.json --pcf go_board.pcf --asc calc.asc || { no_compila "place and route"; return 1; }
    echo; echo "--- bitstream -------------------------------------------------------------"
    icepack calc.asc calc.bin || { no_compila icepack; return 1; }
    echo; echo "Bitstream listo: calc.bin"; echo "Para programar la placa:  ./sim.sh prog"
}

run_prog() {
    if [ ! -f calc.bin ]; then
        echo "No existe calc.bin. Corre primero:  ./sim.sh fpga"; FALLOS=$((FALLOS+1)); return 1
    fi
    iceprog calc.bin || no_compila iceprog
}

borra_sim() {
    echo; echo "Borrando archivos de simulacion..."
    rm -f sim_adder4* sim_shifter* sim_opsel* sim_alu* sim_display* \
          sim_debounce* sim_control* sim_calc* sim_top* sim_demo* sim_wave* *.vcd
}

resumen() {
    if [ "$FALLOS" -eq 0 ]; then
        echo "  TODO OK -- ningun testbench reporto errores"
    else
        echo "  *** $FALLOS testbench con problemas -- revisar arriba ***"
    fi
}

TARGET="${1:-all}"
case "$TARGET" in
    all)
        run_adder4; run_shifter; run_opsel; run_alu; run_display; run_debounce; run_control; run_calc
        echo; echo "====================================================================="
        resumen
        echo "Falta './sim.sh top' (lento, 2-3 min) y './sim.sh fpga'."
        echo "====================================================================="
        ;;
    adder4)    run_adder4 ;;
    shifter)   run_shifter ;;
    opsel)     run_opsel ;;
    alu)       run_alu ;;
    display)   run_display ;;
    debounce)  run_debounce ;;
    control)   run_control ;;
    calc)      run_calc ;;
    top)       run_top ;;
    demo)      run_demo ;;
    wave)      run_wave ;;
    fpga)      run_fpga ;;
    prog)      run_prog ;;
    clean)     borra_sim; echo "Listo. El bitstream (calc.bin) NO se toco: para borrarlo, ./sim.sh distclean" ;;
    distclean) borra_sim; echo "Borrando el bitstream..."; rm -f calc.json calc.asc calc.bin; echo "Listo." ;;
    *)
        echo "Objetivo desconocido: $TARGET"
        echo "Opciones: all adder4 shifter opsel alu display debounce control"
        echo "          calc top demo wave fpga prog clean distclean"
        FALLOS=1
        ;;
esac

exit "$FALLOS"
