//=====================================================================
// adder4_tb.v -- Testbench exhaustivo del sumador de 4 bits
//
// 512 casos: 16 valores de A x 16 de B x 2 valores de cin.
// Verifica suma y carry de salida contra el modelo de referencia.
//
// SIN if NI case: el conteo usa (obtenido !== esperado), que entrega
// 1 o 0 y se acumula directo; el veredicto es un string indexado.
//=====================================================================

`timescale 1ns/1ps

module adder4_tb;

    reg  [3:0] a, b;
    reg        cin;
    wire [3:0] sum;
    wire       cout;

    integer errores, casos;
    integer i, j, k;

    reg       hubo;
    reg [3:0] mal_a, mal_b;
    reg       mal_cin;
    reg [4:0] mal_r, mal_e;

    reg [79:0] veredicto [0:1];

    adder4 uut (a, b, cin, sum, cout);

    task chequea;
        input [4:0] esperado;
        reg mal, nuevo;
        begin
            casos   = casos + 1;
            mal     = ({cout, sum} !== esperado);
            nuevo   = mal & ~hubo;
            errores = errores + mal;

            mal_a   = ({4{nuevo}} & a)            | ({4{~nuevo}} & mal_a);
            mal_b   = ({4{nuevo}} & b)            | ({4{~nuevo}} & mal_b);
            mal_cin = (nuevo & cin)               | (~nuevo & mal_cin);
            mal_r   = ({5{nuevo}} & {cout, sum})  | ({5{~nuevo}} & mal_r);
            mal_e   = ({5{nuevo}} & esperado)     | ({5{~nuevo}} & mal_e);
            hubo    = hubo | mal;
        end
    endtask

    initial begin
        $dumpfile("adder4.vcd");
        $dumpvars(0, adder4_tb);

        veredicto[0] = "TODO OK   ";
        veredicto[1] = "HAY FALLAS";

        errores = 0; casos = 0; hubo = 0;
        mal_a = 0; mal_b = 0; mal_cin = 0; mal_r = 0; mal_e = 0;

        $display("=====================================================");
        $display(" adder4 -- barrido exhaustivo (512 casos)");
        $display("=====================================================");

        for (k = 0; k < 2; k = k + 1)
            for (i = 0; i < 16; i = i + 1)
                for (j = 0; j < 16; j = j + 1) begin
                    a = i; b = j; cin = k;
                    #1;
                    chequea(a + b + cin);
                end

        $display("");
        $display("Casos probados : %0d", casos);
        $display("Errores        : %0d", errores);
        $display("Primer fallo   : a=%b b=%b cin=%b  {cout,sum}=%b esperado=%b   <- solo vale si Errores > 0",
                 mal_a, mal_b, mal_cin, mal_r, mal_e);
        $display("");
        $display(">>> adder4: %s", veredicto[hubo]);

        $finish;
    end

endmodule
