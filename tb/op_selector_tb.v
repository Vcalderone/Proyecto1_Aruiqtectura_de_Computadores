//=====================================================================
// op_selector_tb.v -- Testbench del contador up/down modulo 6
//
// Verifica:
//   - reset sincrono
//   - vuelta completa subiendo, con wrap 101 -> 000
//   - vuelta completa bajando, con wrap 000 -> 101
//   - retencion del valor sin pulsos
//   - prioridad de inc sobre dec cuando ambos estan activos
//   - que el estado nunca entre en 110 ni 111
//
// SIN if NI case. El chequeo de estado ilegal aprovecha que
// (q2 AND q1) vale 1 exactamente para 110 y 111, asi que se acumula
// como si fuera un contador de errores.
//=====================================================================

`timescale 1ns/1ps

module op_selector_tb;

    reg        clk;
    reg        rst, inc, dec;
    wire [2:0] op;

    integer errores, ilegales, casos;
    integer i;

    reg       hubo;
    reg [2:0] mal_r, mal_e;

    reg [79:0] veredicto [0:1];

    op_selector uut (clk, rst, inc, dec, op);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //-----------------------------------------------------------------
    // Estado ilegal: op2 AND op1 vale 1 solo en 110 y 111
    //-----------------------------------------------------------------
    always @(posedge clk) begin
        #1;
        ilegales = ilegales + (op[2] & op[1]);
    end

    task ciclo;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task verifica;
        input [2:0] esperado;
        reg mal, nuevo;
        begin
            casos   = casos + 1;
            mal     = (op !== esperado);
            nuevo   = mal & ~hubo;
            errores = errores + mal;
            mal_r   = ({3{nuevo}} & op)       | ({3{~nuevo}} & mal_r);
            mal_e   = ({3{nuevo}} & esperado) | ({3{~nuevo}} & mal_e);
            hubo    = hubo | mal;
        end
    endtask

    //-----------------------------------------------------------------
    initial begin
        $dumpfile("op_selector.vcd");
        $dumpvars(0, op_selector_tb);

        veredicto[0] = "TODO OK   ";
        veredicto[1] = "HAY FALLAS";

        errores = 0; ilegales = 0; casos = 0; hubo = 0;
        mal_r = 0; mal_e = 0;

        rst = 1; inc = 0; dec = 0;

        $display("=====================================================");
        $display(" op_selector -- contador up/down modulo 6");
        $display("=====================================================");

        // Reset
        ciclo;
        verifica(3'b000);
        rst = 0;

        // Subida completa: 000 -> 001 -> ... -> 101 -> 000
        $display("--- Subiendo --------------------------------------");
        inc = 1; dec = 0;
        for (i = 1; i <= 6; i = i + 1) begin
            ciclo;
            $display("  paso %0d: op = %b", i, op);
            verifica(i % 6);
        end
        inc = 0;

        // Retencion: sin pulsos el valor no cambia
        $display("--- Reteniendo ------------------------------------");
        for (i = 0; i < 3; i = i + 1) begin
            ciclo;
            verifica(3'b000);
        end
        $display("  op = %b tras 3 ciclos sin pulso", op);

        // Bajada completa: 000 -> 101 -> 100 -> ... -> 000
        $display("--- Bajando ---------------------------------------");
        inc = 0; dec = 1;
        for (i = 1; i <= 6; i = i + 1) begin
            ciclo;
            $display("  paso %0d: op = %b", i, op);
            verifica((6 - (i % 6)) % 6);
        end
        dec = 0;

        // Prioridad: inc gana sobre dec
        $display("--- inc y dec simultaneos (gana inc) --------------");
        inc = 1; dec = 1;
        ciclo;
        $display("  op = %b", op);
        verifica(3'b001);
        ciclo;
        $display("  op = %b", op);
        verifica(3'b010);
        inc = 0; dec = 0;

        // Reset desde un valor cualquiera
        $display("--- Reset desde 010 -------------------------------");
        rst = 1;
        ciclo;
        verifica(3'b000);
        $display("  op = %b", op);
        rst = 0;

        $display("");
        $display("Casos probados  : %0d", casos);
        $display("Errores         : %0d", errores);
        $display("Estados ilegales: %0d", ilegales);
        $display("Primer fallo    : op=%b esperado=%b   <- solo vale si Errores > 0",
                 mal_r, mal_e);
        $display("");

        $display(">>> op_selector: %s", veredicto[hubo | (ilegales !== 0)]);

        $finish;
    end

endmodule
