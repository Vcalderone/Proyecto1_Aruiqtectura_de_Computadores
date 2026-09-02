//=====================================================================
// display_tb.v -- Testbench de la cadena de display
//
// Tres niveles, todos contra tablas de referencia sacadas del informe:
//
//   1. abs4          16 casos, contra la tabla 3.7
//   2. seg7_decoder   9 casos validos, contra la tabla 3.8
//                     + los 7 don't-care se muestran, no se verifican
//   3. display_chain 64 casos, 4 estados x 16 valores, punta a punta
//
// SIN if NI case. Las tablas de referencia son arreglos indexados, que
// ademas es la forma mas directa de contrastar contra el informe: si
// el arreglo no calza con la tabla impresa, se ve a simple vista.
//=====================================================================

`timescale 1ns/1ps

module display_tb;

    reg  [3:0] v_s0, a, b, r;
    reg        s1, s0;
    wire [3:0] v, d;
    wire       signo;
    wire [6:0] seg_izq, seg_der;

    integer errores, casos;
    integer i, k;

    reg       hubo;
    reg [79:0] veredicto [0:1];

    // Tabla 3.7: magnitud esperada para cada patron de V
    reg [3:0] t_mag [0:15];

    // Tabla 3.8: patron {a,b,c,d,e,f,g} para cada magnitud 0..8
    reg [6:0] t_seg [0:8];

    // Nombres de segmento, para imprimir el dibujo
    reg [7:0] letra [0:6];

    display_chain uut (v_s0, a, b, r, s1, s0, v, signo, d, seg_izq, seg_der);

    // Instancia suelta del decodificador: permite forzar D = 0..15
    // directo, sin pasar por abs4 (que nunca produce 9..15).
    reg  [3:0] dtest;
    wire [6:0] seg_solo;
    seg7_decoder solo (dtest, seg_solo);

    //-----------------------------------------------------------------
    function integer con_signo;
        input [3:0] x;
        begin
            con_signo = x - (16 * x[3]);
        end
    endfunction

    task cuenta;
        input mal;
        begin
            casos   = casos + 1;
            errores = errores + mal;
            hubo    = hubo | mal;
        end
    endtask

    // Dibuja los segmentos encendidos como "abcdefg", "." si apagado.
    // Sin operador ternario: mascara de bits sobre los codigos ASCII.
    function [7:0] pinta;
        input       on;
        input [7:0] c;
        begin
            pinta = ({8{on}} & c) | ({8{~on}} & ".");
        end
    endfunction

    function [55:0] dibujo;
        input [6:0] s;
        begin
            dibujo = { pinta(s[6], "a"), pinta(s[5], "b"), pinta(s[4], "c"),
                       pinta(s[3], "d"), pinta(s[2], "e"), pinta(s[1], "f"),
                       pinta(s[0], "g") };
        end
    endfunction

    //-----------------------------------------------------------------
    initial begin
        $dumpfile("display.vcd");
        $dumpvars(0, display_tb);
        $timeformat(-9, 0, " ns", 8);

        veredicto[0] = "TODO OK   ";
        veredicto[1] = "HAY FALLAS";

        // --- Tabla 3.7 : V -> |V| -----------------------------------
        t_mag[ 0] = 4'b0000;  t_mag[ 1] = 4'b0001;
        t_mag[ 2] = 4'b0010;  t_mag[ 3] = 4'b0011;
        t_mag[ 4] = 4'b0100;  t_mag[ 5] = 4'b0101;
        t_mag[ 6] = 4'b0110;  t_mag[ 7] = 4'b0111;
        t_mag[ 8] = 4'b1000;  t_mag[ 9] = 4'b0111;
        t_mag[10] = 4'b0110;  t_mag[11] = 4'b0101;
        t_mag[12] = 4'b0100;  t_mag[13] = 4'b0011;
        t_mag[14] = 4'b0010;  t_mag[15] = 4'b0001;

        // --- Tabla 3.8 : magnitud -> {a,b,c,d,e,f,g} ----------------
        t_seg[0] = 7'b1111110;   t_seg[1] = 7'b0110000;
        t_seg[2] = 7'b1101101;   t_seg[3] = 7'b1111001;
        t_seg[4] = 7'b0110011;   t_seg[5] = 7'b1011011;
        t_seg[6] = 7'b1011111;   t_seg[7] = 7'b1110000;
        t_seg[8] = 7'b1111111;

        errores = 0; casos = 0; hubo = 0;
        v_s0 = 0; a = 0; b = 0; r = 0; s1 = 0; s0 = 0; dtest = 0;

        $display("=====================================================");
        $display(" Cadena de display -- abs4 + seg7 + mux de fuente");
        $display("=====================================================");

        //-------------------------------------------------------------
        // 1. abs4 contra la tabla 3.7
        //-------------------------------------------------------------
        $display("--- abs4 : V -> signo + magnitud (tabla 3.7) ------");
        s1 = 1; s0 = 1;                       // estado S3, muestra r
        for (i = 0; i < 16; i = i + 1) begin
            r = i;
            #1;
            cuenta((d !== t_mag[i]) | (signo !== r[3]));
            $display("  V=%b (%3d)   signo=%b   D=%b (%0d)",
                     r, con_signo(r), signo, d, d);
        end
        $display("");

        //-------------------------------------------------------------
        // 2. seg7_decoder contra la tabla 3.8, valores validos 0..8
        //-------------------------------------------------------------
        $display("--- seg7 : magnitud 0..8 (tabla 3.8) --------------");
        for (i = 0; i < 9; i = i + 1) begin
            dtest = i;
            #1;
            cuenta(seg_solo !== t_seg[i]);
            $display("  D=%b (%0d)   seg=%b   %0s",
                     dtest, i, seg_solo, dibujo(seg_solo));
        end
        $display("");

        //-------------------------------------------------------------
        // 3. Don't-cares 9..15: inalcanzables, solo se reportan
        //-------------------------------------------------------------
        $display("--- seg7 : don't-care 9..15 (no se verifican) -----");
        for (i = 9; i < 16; i = i + 1) begin
            dtest = i;
            #1;
            $display("  D=%b (%2d)   seg=%b   %0s   <- patron basura, inalcanzable",
                     dtest, i, seg_solo, dibujo(seg_solo));
        end
        $display("");

        //-------------------------------------------------------------
        // 3b. Por que los don't-care son seguros: abs4 nunca los produce.
        //     D <= 8  equivale a  NOT( D3 AND (D2 OR D1 OR D0) ).
        //     Se comprueba sin usar '>' ni 'if'.
        //-------------------------------------------------------------
        $display("--- abs4 nunca produce 9..15 ----------------------");
        s1 = 1; s0 = 1;
        for (i = 0; i < 16; i = i + 1) begin
            r = i;
            #1;
            cuenta(d[3] & (d[2] | d[1] | d[0]));
        end
        $display("  16 valores de V comprobados: D siempre en 0..8, errores %0d",
                 errores);
        $display("");

        //-------------------------------------------------------------
        // 4. Display de signo
        //-------------------------------------------------------------
        $display("--- seg7_signo : display izquierdo ----------------");
        s1 = 1; s0 = 1;
        r = 4'b0011;  #1;
        cuenta(seg_izq !== 7'b0000000);
        $display("  V=%b (+3)  seg_izq=%b   %0s", r, seg_izq, dibujo(seg_izq));
        r = 4'b1101;  #1;
        cuenta(seg_izq !== 7'b0000001);
        $display("  V=%b (-3)  seg_izq=%b   %0s", r, seg_izq, dibujo(seg_izq));
        $display("");

        //-------------------------------------------------------------
        // 5. display_src : 4 estados x 16 valores, punta a punta
        //-------------------------------------------------------------
        $display("--- display_src : el estado elige la fuente -------");

        // S0 (00) -> v_s0
        s1 = 0; s0 = 0;
        for (k = 0; k < 16; k = k + 1) begin
            v_s0 = k; a = ~k; b = k + 3; r = k + 7;
            #1;
            cuenta(v !== v_s0[3:0]);
        end
        $display("  S0 (00) -> v_s0 : 16 casos, errores %0d", errores);

        // S1 (01) -> a
        s1 = 0; s0 = 1;
        for (k = 0; k < 16; k = k + 1) begin
            a = k; v_s0 = ~k; b = k + 3; r = k + 7;
            #1;
            cuenta(v !== a);
        end
        $display("  S1 (01) -> A    : 16 casos, errores %0d", errores);

        // S2 (10) -> b
        s1 = 1; s0 = 0;
        for (k = 0; k < 16; k = k + 1) begin
            b = k; v_s0 = ~k; a = k + 3; r = k + 7;
            #1;
            cuenta(v !== b);
        end
        $display("  S2 (10) -> B    : 16 casos, errores %0d", errores);

        // S3 (11) -> r
        s1 = 1; s0 = 1;
        for (k = 0; k < 16; k = k + 1) begin
            r = k; v_s0 = ~k; a = k + 3; b = k + 7;
            #1;
            cuenta(v !== r);
        end
        $display("  S3 (11) -> R    : 16 casos, errores %0d", errores);
        $display("");

        //-------------------------------------------------------------
        // 6. Recorrido legible: como se ve cada resultado en la placa
        //-------------------------------------------------------------
        $display("--- Como se ve en la placa ------------------------");
        s1 = 1; s0 = 1;
        for (i = 0; i < 16; i = i + 1) begin
            r = i;
            #1;
            $display("  R=%b = %3d   ->   izq[%0s]  der[%0s]  (D=%0d)",
                     r, con_signo(r), dibujo(seg_izq), dibujo(seg_der), d);
        end
        $display("");

        $display("Casos verificados : %0d", casos);
        $display("Errores           : %0d", errores);
        $display("");
        $display(">>> cadena de display: %s", veredicto[hubo]);

        $finish;
    end

endmodule
