//=====================================================================
// alu_wave_tb.v -- Testbench de VISUALIZACION de la ALU
//
// No verifica nada: para eso esta alu_tb.v (2048 casos).
// Este recorre 24 casos elegidos a mano, con 20 ns cada uno, para que
// la onda en GTKWave se pueda leer y sirva para la demostracion.
//
// Expone tambien las senales internas: sel_*, sub, swap, sum, shl, shr.
// Se ve el decodificador one-hot activando una sola linea y el
// enmascarado AND+OR dejando pasar solo esa via.
//
// SIN if NI case.
//
//   iverilog -o sim_wave src/full_adder.v src/adder4.v src/mux2.v ^
//            src/shift_left.v src/shift_right.v src/op_decoder.v ^
//            src/alu.v tb/alu_wave_tb.v
//   vvp sim_wave
//   gtkwave alu_wave.vcd alu_wave.gtkw
//=====================================================================

`timescale 1ns/1ps

module alu_wave_tb;

    reg  [3:0] a, b;
    reg  [2:0] op;
    wire [3:0] r;

    alu uut (a, b, op, r);

    //-----------------------------------------------------------------
    // Alias de las senales internas, para que aparezcan en el nivel
    // superior del VCD y no haya que bucear en la jerarquia.
    //-----------------------------------------------------------------
    wire sel_rst  = uut.sel_rst;
    wire sel_add  = uut.sel_add;
    wire sel_sub  = uut.sel_sub;
    wire sel_rsub = uut.sel_rsub;
    wire sel_shl  = uut.sel_shl;
    wire sel_shr  = uut.sel_shr;

    wire       sub  = uut.sub;
    wire       swap = uut.swap;
    wire [3:0] x    = uut.x;      // operando izquierdo tras el swap
    wire [3:0] y    = uut.y;      // operando derecho tras el swap
    wire [3:0] yc   = uut.yc;     // y acondicionado (XOR con sub)
    wire [3:0] sum  = uut.sum;    // salida del adder4
    wire [3:0] shl  = uut.shl;    // salida del shift_left
    wire [3:0] shr  = uut.shr;    // salida del shift_right

    function integer con_signo;
        input [3:0] v;
        begin
            con_signo = v - (16 * v[3]);
        end
    endfunction

    task caso;
        input [3:0] ta;
        input [3:0] tb;
        input [2:0] top;
        begin
            a = ta; b = tb; op = top;
            #20;
            $display("  %0t  op=%b  a=%b(%0d)  b=%b(%0d)  ->  r=%b(%0d)",
                     $time, op, a, con_signo(a), b, con_signo(b),
                     r, con_signo(r));
        end
    endtask

    //-----------------------------------------------------------------
    initial begin
        $dumpfile("alu_wave.vcd");
        $dumpvars(0, alu_wave_tb);
        $timeformat(-9, 0, " ns", 8);

        $display("=====================================================");
        $display(" ALU -- recorrido para la onda (24 casos, 20 ns c/u)");
        $display("=====================================================");

        // --- 000 reinicio: ignora A y B ------------------------------
        $display("--- 000 reinicio ----------------------------------");
        caso(4'b0101, 4'b0011, 3'b000);   //  5, 3   ->  0
        caso(4'b1111, 4'b1111, 3'b000);   // -1,-1   ->  0

        // --- 001 suma ------------------------------------------------
        $display("--- 001 suma --------------------------------------");
        caso(4'b0011, 4'b0010, 3'b001);   //  3 +  2 =  5
        caso(4'b1101, 4'b0010, 3'b001);   // -3 +  2 = -1
        caso(4'b1100, 4'b1110, 3'b001);   // -4 + -2 = -6
        caso(4'b0111, 4'b0001, 3'b001);   //  7 +  1 = -8   wrap mod 16

        // --- 010 resta -----------------------------------------------
        $display("--- 010 resta -------------------------------------");
        caso(4'b0101, 4'b0011, 3'b010);   //  5 -  3 =  2
        caso(4'b0011, 4'b0101, 3'b010);   //  3 -  5 = -2
        caso(4'b1101, 4'b1110, 3'b010);   // -3 - -2 = -1
        caso(4'b1000, 4'b0001, 3'b010);   // -8 -  1 =  7   wrap mod 16

        // --- 011 resta inversa ---------------------------------------
        $display("--- 011 resta inversa -----------------------------");
        caso(4'b0011, 4'b0101, 3'b011);   //  5 -  3 =  2   (mismos operandos
        caso(4'b0101, 4'b0011, 3'b011);   //  3 -  5 = -2    que arriba, al reves)
        caso(4'b0001, 4'b1000, 3'b011);   // -8 -  1 =  7

        // --- 100 shift left ------------------------------------------
        $display("--- 100 shift left --------------------------------");
        caso(4'b0001, 4'b0000, 3'b100);   // 0001 << 0 = 0001
        caso(4'b0001, 4'b0001, 3'b100);   // 0001 << 1 = 0010
        caso(4'b0001, 4'b0010, 3'b100);   // 0001 << 2 = 0100
        caso(4'b0001, 4'b0011, 3'b100);   // 0001 << 3 = 1000
        caso(4'b1011, 4'b1111, 3'b100);   // usa solo b[1:0]=11 -> 1000

        // --- 101 shift right -----------------------------------------
        $display("--- 101 shift right -------------------------------");
        caso(4'b1000, 4'b0000, 3'b101);   // 1000 >> 0 = 1000
        caso(4'b1000, 4'b0001, 3'b101);   // 1000 >> 1 = 0100   logico
        caso(4'b1000, 4'b0010, 3'b101);   // 1000 >> 2 = 0010
        caso(4'b1011, 4'b0011, 3'b101);   // 1011 >> 3 = 0001

        // --- 110 / 111 invalidos: salida segura ----------------------
        $display("--- 110 / 111 invalidos ---------------------------");
        caso(4'b0101, 4'b0011, 3'b110);   // -> 0000, sin sel_* activa
        caso(4'b0101, 4'b0011, 3'b111);   // -> 0000, sin sel_* activa

        $display("");
        $display("Fin en %0t. Abrir con:  gtkwave alu_wave.vcd alu_wave.gtkw",
                 $time);

        $finish;
    end

endmodule
