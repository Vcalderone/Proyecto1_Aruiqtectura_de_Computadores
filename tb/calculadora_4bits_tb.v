//=====================================================================
// calculadora_4bits_tb.v -- Testbench propio del envoltorio de la
//                           evaluacion.
//
// El testbench basico de la catedra (calculadora_4bits_tb_basico.sv)
// solo prueba suma y resta con sel_op2 = 0. Este cubre lo que aquel
// deja afuera, que es justo lo que puede aparecer en la evaluacion:
//
//   1. Valor inicial del registro (antes de cualquier 'ejecutar')
//   2. Las seis operaciones por esta interfaz
//   3. sel_op2 = 1: encadenar usando el resultado anterior
//   4. Retencion: con ejecutar = 0 el resultado no se mueve
//   5. Codigos invalidos 110 y 111
//
// Mismo protocolo de reloj que el testbench de la catedra: 'ejecutar'
// se mantiene en alto durante exactamente un flanco de subida.
//
// SIN if NI case, igual que el resto de los testbenches del proyecto.
//=====================================================================

`timescale 1ns/1ps

module calculadora_4bits_tb;

    reg        clk;
    reg        ejecutar;
    reg  [2:0] codigo;
    reg        sel_op2;
    reg  [3:0] op1;
    reg  [3:0] op2_ext;
    wire [3:0] resultado;

    integer errores, casos;
    reg     hubo;
    reg [79:0] veredicto [0:1];

    localparam [2:0] REINICIO = 3'b000;
    localparam [2:0] SUMA     = 3'b001;
    localparam [2:0] RESTA    = 3'b010;
    localparam [2:0] RESTA_I  = 3'b011;
    localparam [2:0] SHL      = 3'b100;
    localparam [2:0] SHR      = 3'b101;

    calculadora_4bits uut (
        .clk       (clk),
        .ejecutar  (ejecutar),
        .codigo    (codigo),
        .sel_op2   (sel_op2),
        .op1       (op1),
        .op2_ext   (op2_ext),
        .resultado (resultado)
    );

    always #5 clk = ~clk;

    function integer con_signo;
        input [3:0] v;
        begin
            con_signo = v - (16 * v[3]);
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

    //-----------------------------------------------------------------
    // Mismo pulso que usa el testbench de la catedra
    //-----------------------------------------------------------------
    task ejecuta;
        begin
            ejecutar = 1'b1;
            @(posedge clk); #1;
            ejecutar = 1'b0;
            @(posedge clk); #1;
        end
    endtask

    //-----------------------------------------------------------------
    // Operacion con el operando externo (sel_op2 = 0)
    //-----------------------------------------------------------------
    task prueba;
        input [2:0] cod;
        input [3:0] a;
        input [3:0] b;
        input [3:0] esperado;
        begin
            codigo = cod; sel_op2 = 1'b0; op1 = a; op2_ext = b;
            ejecuta;
            cuenta(resultado !== esperado);
            $display("  cod=%b  op1=%4d  op2_ext=%4d  ->  %b (%3d)   esperado %b",
                     cod, con_signo(a), con_signo(b),
                     resultado, con_signo(resultado), esperado);
        end
    endtask

    //-----------------------------------------------------------------
    // Operacion reutilizando el resultado anterior (sel_op2 = 1)
    //-----------------------------------------------------------------
    task prueba_ant;
        input [2:0] cod;
        input [3:0] a;
        input [3:0] esperado;
        begin
            codigo = cod; sel_op2 = 1'b1; op1 = a; op2_ext = 4'bxxxx;
            ejecuta;
            cuenta(resultado !== esperado);
            $display("  cod=%b  op1=%4d  op2=ANTERIOR ->  %b (%3d)   esperado %b",
                     cod, con_signo(a),
                     resultado, con_signo(resultado), esperado);
        end
    endtask

    initial begin
        $dumpfile("calculadora_4bits.vcd");
        $dumpvars(0, calculadora_4bits_tb);

        veredicto[0] = "TODO OK   ";
        veredicto[1] = "HAY FALLAS";

        errores = 0; casos = 0; hubo = 0;
        clk = 1'b0; ejecutar = 1'b0; sel_op2 = 1'b0;
        codigo = 3'b000; op1 = 4'b0000; op2_ext = 4'b0000;

        $display("=====================================================");
        $display(" calculadora_4bits -- interfaz de la evaluacion");
        $display("=====================================================");

        //-------------------------------------------------------------
        $display("--- 1. Valor inicial (sin ejecutar nunca) ---------");
        repeat (2) @(posedge clk); #1;
        cuenta(resultado !== 4'b0000);
        $display("  resultado = %b   esperado 0000  (no debe ser X)", resultado);

        //-------------------------------------------------------------
        $display("--- 2. Las seis operaciones -----------------------");
        prueba(SUMA,     4'b0011, 4'b0100, 4'b0111);  //  3 + 4 =  7
        prueba(RESTA,    4'b0101, 4'b0010, 4'b0011);  //  5 - 2 =  3
        prueba(RESTA_I,  4'b0011, 4'b0101, 4'b0010);  //  5 - 3 =  2
        prueba(SHL,      4'b0011, 4'b0010, 4'b1100);  //  3 << 2 = 12 -> -4
        prueba(SHR,      4'b1000, 4'b0001, 4'b0100);  // -8 >> 1 =  4
        prueba(REINICIO, 4'b0111, 4'b0111, 4'b0000);  //  R = 0

        //-------------------------------------------------------------
        $display("--- 3. Overflow y signo ---------------------------");
        prueba(SUMA,  4'b0111, 4'b0011, 4'b1010);     //  7 + 3 -> -6
        prueba(SUMA,  4'b1110, 4'b0011, 4'b0001);     // -2 + 3 =  1
        prueba(RESTA, 4'b1011, 4'b1110, 4'b1101);     // -5-(-2)= -3

        //-------------------------------------------------------------
        $display("--- 4. sel_op2 = 1: encadenar el resultado --------");
        prueba(SUMA, 4'b0011, 4'b0100, 4'b0111);      // R = 7
        prueba_ant(SUMA,  4'b0001, 4'b1000);          // 1 + 7 = 8 -> -8
        prueba_ant(RESTA, 4'b0010, 4'b1010);          // 2 - (-8) = 10 -> -6
        prueba_ant(SHR,   4'b1000, 4'b0010);          // -8 >> B[1:0]=10 -> 2

        //-------------------------------------------------------------
        $display("--- 5. Retencion con ejecutar = 0 -----------------");
        codigo = SUMA; sel_op2 = 1'b0; op1 = 4'b0111; op2_ext = 4'b0111;
        repeat (6) @(posedge clk); #1;
        cuenta(resultado !== 4'b0010);
        $display("  tras 6 flancos sin ejecutar: %b   esperado 0010 (sin cambio)",
                 resultado);

        //-------------------------------------------------------------
        $display("--- 6. Codigos invalidos --------------------------");
        prueba(3'b110, 4'b0101, 4'b0011, 4'b0000);
        prueba(3'b111, 4'b0101, 4'b0011, 4'b0000);

        //-------------------------------------------------------------
        $display("");
        $display("Casos verificados : %0d", casos);
        $display("Errores           : %0d", errores);
        $display("");
        $display(">>> calculadora_4bits: %s", veredicto[hubo]);
        $finish;
    end

endmodule
