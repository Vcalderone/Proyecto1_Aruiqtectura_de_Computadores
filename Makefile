# Flujo completo: sintesis, place and route, bitstream y programacion
# Requiere OSS CAD Suite en el PATH (start.bat)

SRC  := $(wildcard src/*.v)
TOP  := top
PCF  := go_board.pcf

all: calc.bin

calc.json: $(SRC)
	yosys -p "read_verilog src/*.v; hierarchy -top $(TOP); synth_ice40 -json calc.json"

calc.asc: calc.json $(PCF)
	nextpnr-ice40 --hx1k --package vq100 --freq 25 --json calc.json --pcf $(PCF) --asc calc.asc

calc.bin: calc.asc
	icepack calc.asc calc.bin

prog: calc.bin
	iceprog calc.bin

clean:
	rm -f calc.json calc.asc calc.bin sim_* *.vcd

.PHONY: all prog clean
