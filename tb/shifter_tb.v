//=====================================================================
// shifter_tb.v -- Testbench de los barrel shifters
//
// 64 combinaciones por direccion: 16 valores de A x 4 de sh.
// Verifica desplazamiento LOGICO (rellena ceros) en ambos sentidos.
//
// SIN if NI case: conteo con (obtenido !== esperado), veredicto por
// string indexado.
//=====================================================================

`timescale 1ns/1ps

module shifter_tb;

    reg  [3:0] a;
    reg  [1:0] sh;
    wire [3:0] yl, yr;

    integer errores_l, errores_r, casos;
    integer i, j;

    reg       hubo_l, hubo_r;
    reg [3:0] mal_al, mal_rl, mal_el;
    reg [1:0] mal_shl;
    reg [3:0] mal_ar, mal_rr, mal_er;
    reg [1:0] mal_shr;

    reg [79:0] veredicto [0:1];

    shift_left  uut_l (a, sh, yl);
    shift_right uut_r (a, sh, yr);

    task chequea;
        input [3:0] esp_l;
        input [3:0] esp_r;
        reg mal_izq, nuevo_izq;
        reg mal_der, nuevo_der;
        begin
            casos = casos + 1;

            mal_izq   = (yl !== esp_l);
            nuevo_izq = mal_izq & ~hubo_l;
            errores_l = errores_l + mal_izq;
            mal_al    = ({4{nuevo_izq}} & a)     | ({4{~nuevo_izq}} & mal_al);
            mal_shl   = ({2{nuevo_izq}} & sh)    | ({2{~nuevo_izq}} & mal_shl);
            mal_rl    = ({4{nuevo_izq}} & yl)    | ({4{~nuevo_izq}} & mal_rl);
            mal_el    = ({4{nuevo_izq}} & esp_l) | ({4{~nuevo_izq}} & mal_el);
            hubo_l    = hubo_l | mal_izq;

            mal_der   = (yr !== esp_r);
            nuevo_der = mal_der & ~hubo_r;
            errores_r = errores_r + mal_der;
            mal_ar    = ({4{nuevo_der}} & a)     | ({4{~nuevo_der}} & mal_ar);
            mal_shr   = ({2{nuevo_der}} & sh)    | ({2{~nuevo_der}} & mal_shr);
            mal_rr    = ({4{nuevo_der}} & yr)    | ({4{~nuevo_der}} & mal_rr);
            mal_er    = ({4{nuevo_der}} & esp_r) | ({4{~nuevo_der}} & mal_er);
            hubo_r    = hubo_r | mal_der;
        end
    endtask

    initial begin
        $dumpfile("shifter.vcd");
        $dumpvars(0, shifter_tb);

        veredicto[0] = "TODO OK   ";
        veredicto[1] = "HAY FALLAS";

        errores_l = 0; errores_r = 0; casos = 0;
        hubo_l = 0; hubo_r = 0;
        mal_al = 0; mal_shl = 0; mal_rl = 0; mal_el = 0;
        mal_ar = 0; mal_shr = 0; mal_rr = 0; mal_er = 0;

        $display("=====================================================");
        $display(" shift_left / shift_right -- barrido exhaustivo");
        $display("=====================================================");

        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                a = i; sh = j;
                #1;
                chequea(a << sh, a >> sh);
            end

        $display("");
        $display("Casos probados     : %0d por direccion", casos);
        $display("Errores izquierda  : %0d", errores_l);
        $display("Errores derecha    : %0d", errores_r);
        $display("Primer fallo izq   : a=%b sh=%b y=%b esperado=%b   <- solo vale si Errores izq > 0",
                 mal_al, mal_shl, mal_rl, mal_el);
        $display("Primer fallo der   : a=%b sh=%b y=%b esperado=%b   <- solo vale si Errores der > 0",
                 mal_ar, mal_shr, mal_rr, mal_er);
        $display("");

        //-------------------------------------------------------------
        // Tabla de la seccion 3.6 del informe, con A = 1011
        //-------------------------------------------------------------
        $display("--- A = 1011 (tabla 3.6) --------------------------");
        a = 4'b1011;
        for (j = 0; j < 4; j = j + 1) begin
            sh = j;
            #1;
            $display("  sh=%b   izq=%b   der=%b", sh, yl, yr);
        end
        $display("");

        $display(">>> shifters: %s", veredicto[hubo_l | hubo_r]);

        $finish;
    end

endmodule
