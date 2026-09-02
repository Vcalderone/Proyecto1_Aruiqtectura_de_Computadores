//=====================================================================
// alu_tb.v -- Testbench exhaustivo de la ALU
//
// 2048 casos: 8 codigos de operacion x 16 valores de A x 16 de B.
//
// SIN if NI case, tampoco en el testbench. Tecnicas usadas:
//
//   conteo      errores = errores + (obtenido !== esperado)
//               el operador !== entrega 1 o 0, se acumula directo
//
//   seleccion   un lazo por operacion, con su expresion de referencia
//               escrita explicita, en vez de un case sobre op
//
//   captura     mascara {N{bit}} para quedarse con el primer caso malo,
//               en vez de una asignacion condicional
//
//   veredicto   string indexado desde un arreglo, en vez de if/else
//
//   one-hot     esperado = NOT(op2 AND op1): vale 1 para 000..101
//               y 0 para los codigos invalidos 110 y 111
//=====================================================================

`timescale 1ns/1ps

module alu_tb;

    reg  [3:0] a, b;
    reg  [2:0] op;
    wire [3:0] r;

    integer errores, fallas_oh, casos, base;
    integer i, j;

    // Captura del primer caso malo
    reg       hubo;
    reg [2:0] mal_op;
    reg [3:0] mal_a, mal_b, mal_r, mal_e;

    reg [79:0] veredicto [0:1];

    alu uut (a, b, op, r);

    //-----------------------------------------------------------------
    // Propiedad one-hot del decodificador
    //-----------------------------------------------------------------
    wire [2:0] activas = uut.sel_rst  + uut.sel_add + uut.sel_sub
                       + uut.sel_rsub + uut.sel_shl + uut.sel_shr;

    wire       esp_act = ~(op[2] & op[1]);

    //-----------------------------------------------------------------
    task chequea;
        input [3:0] esperado;
        reg mal, nuevo;
        begin
            casos     = casos + 1;
            mal       = (r !== esperado);
            nuevo     = mal & ~hubo;
            errores   = errores + mal;
            fallas_oh = fallas_oh + (activas !== esp_act);

            mal_op = ({3{nuevo}} & op)       | ({3{~nuevo}} & mal_op);
            mal_a  = ({4{nuevo}} & a)        | ({4{~nuevo}} & mal_a);
            mal_b  = ({4{nuevo}} & b)        | ({4{~nuevo}} & mal_b);
            mal_r  = ({4{nuevo}} & r)        | ({4{~nuevo}} & mal_r);
            mal_e  = ({4{nuevo}} & esperado) | ({4{~nuevo}} & mal_e);
            hubo   = hubo | mal;
        end
    endtask

    function integer con_signo;
        input [3:0] v;
        begin
            con_signo = v - (16 * v[3]);
        end
    endfunction

    task muestra;
        input [3:0] ta;
        input [3:0] tb;
        input [2:0] top;
        begin
            a = ta; b = tb; op = top;
            #1;
            $display("  op=%b  a=%b(%0d)  b=%b(%0d)  ->  r=%b(%0d)",
                     op, a, con_signo(a), b, con_signo(b), r, con_signo(r));
        end
    endtask

    //-----------------------------------------------------------------
    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_tb);

        veredicto[0] = "TODO OK   ";
        veredicto[1] = "HAY FALLAS";

        errores = 0; fallas_oh = 0; casos = 0; hubo = 0;
        mal_op = 0; mal_a = 0; mal_b = 0; mal_r = 0; mal_e = 0;

        $display("=====================================================");
        $display(" ALU 4 bits -- barrido exhaustivo (2048 casos)");
        $display("=====================================================");

        // --- 000 reinicio: ignora A y B ------------------------------
        base = errores; op = 3'b000;
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j; #1; chequea(4'b0000);
            end
        $display("  000  reinicio        errores: %0d", errores - base);

        // --- 001 suma ------------------------------------------------
        base = errores; op = 3'b001;
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j; #1; chequea(a + b);
            end
        $display("  001  suma            errores: %0d", errores - base);

        // --- 010 resta -----------------------------------------------
        base = errores; op = 3'b010;
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j; #1; chequea(a - b);
            end
        $display("  010  resta           errores: %0d", errores - base);

        // --- 011 resta inversa ---------------------------------------
        base = errores; op = 3'b011;
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j; #1; chequea(b - a);
            end
        $display("  011  resta inversa   errores: %0d", errores - base);

        // --- 100 shift left ------------------------------------------
        base = errores; op = 3'b100;
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j; #1; chequea(a << b[1:0]);
            end
        $display("  100  shift left      errores: %0d", errores - base);

        // --- 101 shift right -----------------------------------------
        base = errores; op = 3'b101;
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j; #1; chequea(a >> b[1:0]);
            end
        $display("  101  shift right     errores: %0d", errores - base);

        // --- 110 invalido: salida segura 0000 ------------------------
        base = errores; op = 3'b110;
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j; #1; chequea(4'b0000);
            end
        $display("  110  invalido        errores: %0d", errores - base);

        // --- 111 invalido: salida segura 0000 ------------------------
        base = errores; op = 3'b111;
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j; #1; chequea(4'b0000);
            end
        $display("  111  invalido        errores: %0d", errores - base);

        $display("");
        $display("Casos probados : %0d", casos);
        $display("Errores        : %0d", errores);
        $display("Fallas one-hot : %0d", fallas_oh);
        $display("Primer fallo   : op=%b a=%b b=%b r=%b esperado=%b   <- solo vale si Errores > 0",
                 mal_op, mal_a, mal_b, mal_r, mal_e);
        $display("");

        //-------------------------------------------------------------
        $display("--- Casos con signo -------------------------------");
        muestra(4'b0011, 4'b0010, 3'b001);   //  3 +  2 =  5
        muestra(4'b0011, 4'b0101, 3'b010);   //  3 -  5 = -2
        muestra(4'b0101, 4'b0011, 3'b011);   //  3 -  5 = -2  (invertida)
        muestra(4'b1101, 4'b0010, 3'b001);   // -3 +  2 = -1
        muestra(4'b1000, 4'b0001, 3'b010);   // -8 -  1 = +7  (mod 16)
        muestra(4'b0111, 4'b0001, 3'b001);   //  7 +  1 = -8  (mod 16)
        muestra(4'b0001, 4'b0010, 3'b100);   //  1 << 2 =  4
        muestra(4'b1000, 4'b0001, 3'b101);   // -8 >> 1 =  4  (logico)
        muestra(4'b0110, 4'b1011, 3'b100);   // usa solo b[1:0] = 11
        muestra(4'b0101, 4'b0111, 3'b000);   // reinicio ignora a y b
        muestra(4'b0101, 4'b0011, 3'b110);   // invalido -> 0000
        muestra(4'b0101, 4'b0011, 3'b111);   // invalido -> 0000
        $display("");

        $display(">>> ALU: %s", veredicto[hubo | (fallas_oh !== 0)]);

        $finish;
    end

endmodule
