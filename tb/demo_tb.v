//=====================================================================
// demo_tb.v -- Testbench para la evaluacion presencial
//
// El enunciado dice: "se indicaran las operaciones y los valores que
// deberan utilizarse. Cada grupo debera ingresar estos parametros en
// el testbench, ejecutar la simulacion y mostrar los resultados
// obtenidos en GTKWave."
//
// Este archivo es para eso. Se edita UN SOLO BLOQUE, marcado abajo.
//
//   sim.bat demo
//   gtkwave demo.vcd tb/demo.gtkw
//
// Los valores se escriben en DECIMAL CON SIGNO, de -8 a 7:
//
//   caso( 3,  2, SUMA);      ->  3 + 2
//   caso(-5,  1, RESTA);     -> -5 - 1
//   caso( 6,  3, SHL);       ->  6 << 3
//
// Tambien acepta patrones de bits si los piden asi:
//
//   caso(4'b1011, 4'b0010, SUMA);
//
// Cada caso dura 20 ns, para que la onda se pueda leer.
//=====================================================================

`timescale 1ns/1ps

module demo_tb;

    //-----------------------------------------------------------------
    // Nombres de las operaciones
    //-----------------------------------------------------------------
    localparam [2:0] REINICIO = 3'b000;
    localparam [2:0] SUMA     = 3'b001;
    localparam [2:0] RESTA    = 3'b010;   // A - B
    localparam [2:0] RESTA_I  = 3'b011;   // B - A
    localparam [2:0] SHL      = 3'b100;   // A << B[1:0]
    localparam [2:0] SHR      = 3'b101;   // A >> B[1:0]

    reg  [3:0] a, b;
    reg  [2:0] op;
    wire [3:0] r;

    alu uut (a, b, op, r);

    // Internas, para verlas en la onda
    wire sel_rst  = uut.sel_rst;
    wire sel_add  = uut.sel_add;
    wire sel_sub  = uut.sel_sub;
    wire sel_rsub = uut.sel_rsub;
    wire sel_shl  = uut.sel_shl;
    wire sel_shr  = uut.sel_shr;
    wire       sub = uut.sub;
    wire       swp = uut.swap;
    wire [3:0] sum = uut.sum;
    wire [3:0] shl = uut.shl;
    wire [3:0] shr = uut.shr;

    reg [63:0] nombre [0:7];   // 8 caracteres = 64 bits

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
            $display("  %3d  %-8s %3d   ->   %4d      (%b %b %b -> %b)",
                     con_signo(a), nombre[top], con_signo(b),
                     con_signo(r), a, op, b, r);
        end
    endtask

    initial begin
        $dumpfile("demo.vcd");
        $dumpvars(0, demo_tb);
        $timeformat(-9, 0, " ns", 8);

        nombre[0] = "REINICIO"; nombre[1] = "SUMA    ";
        nombre[2] = "RESTA   "; nombre[3] = "RESTA_I ";
        nombre[4] = "SHL     "; nombre[5] = "SHR     ";
        nombre[6] = "INVALIDO"; nombre[7] = "INVALIDO";

        a = 0; b = 0; op = 0;

        $display("=====================================================");
        $display(" Calculadora 4 bits -- casos de la evaluacion");
        $display("=====================================================");
        $display("    A  operacion    B   ->  resultado");
        $display("  ---------------------------------------------------");

        //=============================================================
        //
        //   >>>>>>  EDITAR SOLO DE ACA PARA ABAJO  <<<<<<
        //
        //   Formato:  caso(A, operacion, B) en decimal con signo
        //   Operaciones: REINICIO SUMA RESTA RESTA_I SHL SHR
        //
        //=============================================================

        caso( 3, 2, SUMA   );
        caso( 5, 3, RESTA  );
        caso( 3, 5, RESTA  );
        caso( 3, 5, RESTA_I);
        caso(-4, 2, SUMA   );
        caso( 1, 2, SHL    );
        caso(-8, 1, SHR    );
        caso( 7, 7, REINICIO);

        //=============================================================
        //
        //   >>>>>>  EDITAR SOLO DE ACA PARA ARRIBA  <<<<<<
        //
        //=============================================================

        $display("  ---------------------------------------------------");
        $display("");
        $display("Onda lista. Abrir con:");
        $display("  gtkwave demo.vcd tb/demo.gtkw");

        $finish;
    end

endmodule
