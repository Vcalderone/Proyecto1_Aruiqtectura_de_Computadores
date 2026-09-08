`timescale 1ns/1ps
//=====================================================================
// calculadora_4bits_tb_definitivo.sv -- prueba maxima de la interfaz
//   calculadora_4bits: cobertura combinacional EXHAUSTIVA completa
//   (las ~4096 combinaciones unicas de entrada/estado posibles) mas
//   una maratona aleatoria de 50.000 operaciones encadenadas para
//   estresar la realimentacion (sel_op2=1) a lo largo de una
//   secuencia larga, como una sesion real muy extensa de uso.
//
// No aborta al primer fallo: cuenta errores, imprime como maximo los
// primeros 20 en detalle, y da un resumen final con el total real
// de casos y errores.
//=====================================================================

module calculadora_4bits_tb_definitivo;

  logic clk;
  logic ejecutar;
  logic [2:0] codigo;
  logic sel_op2;
  logic [3:0] op1;
  logic [3:0] op2_ext;
  logic [3:0] resultado;

  calculadora_4bits dut (
    .clk(clk),
    .ejecutar(ejecutar),
    .codigo(codigo),
    .sel_op2(sel_op2),
    .op1(op1),
    .op2_ext(op2_ext),
    .resultado(resultado)
  );

  localparam RST   = 3'b000;
  localparam SUMA  = 3'b001;
  localparam RESTA = 3'b010;
  localparam RINV  = 3'b011;
  localparam SHL   = 3'b100;
  localparam SHR   = 3'b101;

  localparam integer NUM_ALEATORIOS = 50000;

  integer total_casos;
  integer errores;
  integer seed;
  integer i, j, k;
  integer r_cod, r_a, r_b, r_sel;

  always #5 clk = ~clk;

  task automatic pulso_ejecutar;
    begin
      ejecutar = 1'b1;
      @(posedge clk);
      #1;
      ejecutar = 1'b0;
      @(posedge clk);
      #1;
    end
  endtask

  function automatic [3:0] esperado_calc(input [2:0] cod, input [3:0] a, input [3:0] b);
    case (cod)
      3'b000: esperado_calc = 4'b0000;
      3'b001: esperado_calc = a + b;
      3'b010: esperado_calc = a - b;
      3'b011: esperado_calc = b - a;
      3'b100: esperado_calc = a << b[1:0];
      3'b101: esperado_calc = a >> b[1:0];
      default: esperado_calc = 4'b0000;
    endcase
  endfunction

  // Nucleo unico de verificacion: usa el 'resultado' actual del DUT
  // (antes del pulso) como segundo operando cuando sel_op2=1, tal
  // como especifica la interfaz.
  task automatic ejecutar_y_verificar(input [2:0] cod, input [3:0] a, input [3:0] b_ext, input sel);
    logic [3:0] b_efectivo;
    logic [3:0] esperado;
    begin
      b_efectivo = sel ? resultado : b_ext;
      esperado   = esperado_calc(cod, a, b_efectivo);

      codigo  = cod;
      op1     = a;
      op2_ext = b_ext;
      sel_op2 = sel;
      pulso_ejecutar();

      total_casos = total_casos + 1;
      if (resultado !== esperado) begin
        errores = errores + 1;
        if (errores <= 20)
          $display("FAIL #%0d: codigo=%b op1=%b op2_ext=%b sel_op2=%b (b_efectivo=%b) esperado=%b obtenido=%b",
                    total_casos, cod, a, b_ext, sel, b_efectivo, esperado, resultado);
      end
    end
  endtask

  initial begin
    $dumpfile("calculadora_4bits_tb_definitivo.vcd");
    $dumpvars(0, calculadora_4bits_tb_definitivo);

    clk = 1'b0; ejecutar = 1'b0; codigo = 3'b000; sel_op2 = 1'b0;
    op1 = 4'b0000; op2_ext = 4'b0000;
    total_casos = 0; errores = 0;
    seed = 32'h1234_5678;   // semilla fija: los mismos 50.000 casos en cada corrida
    repeat (2) @(posedge clk);

    $display("=====================================================");
    $display("1. Exhaustivo sel_op2=0: 8 codigos x 16 x 16 = 2048 casos");
    $display("=====================================================");
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 16; j = j + 1) begin
        for (k = 0; k < 16; k = k + 1) begin
          ejecutar_y_verificar(i[2:0], j[3:0], k[3:0], 1'b0);
        end
      end
      $display("  ... codigo %0d listo (%0d casos, %0d errores acumulados)", i, total_casos, errores);
    end

    $display("=====================================================");
    $display("2. Exhaustivo sel_op2=1: 16 R_anterior x 8 codigos x 16 op1");
    $display("=====================================================");
    for (i = 0; i < 16; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        for (k = 0; k < 16; k = k + 1) begin
          ejecutar_y_verificar(SUMA, i[3:0], 4'b0000, 1'b0);      // fija R = i
          ejecutar_y_verificar(j[2:0], k[3:0], 4'b0000, 1'b1);    // prueba real con R=i
        end
      end
      $display("  ... R_anterior=%0d listo (%0d casos, %0d errores acumulados)", i, total_casos, errores);
    end

    $display("=====================================================");
    $display("3. Maratona aleatoria: %0d operaciones encadenadas", NUM_ALEATORIOS);
    $display("=====================================================");
    for (i = 0; i < NUM_ALEATORIOS; i = i + 1) begin
      r_cod = $random(seed);
      r_a   = $random(seed);
      r_b   = $random(seed);
      r_sel = $random(seed);
      ejecutar_y_verificar(r_cod[2:0], r_a[3:0], r_b[3:0], r_sel[0]);
      if ((i+1) % 10000 == 0)
        $display("  ... %0d/%0d aleatorios listos (%0d errores acumulados)", i+1, NUM_ALEATORIOS, errores);
    end

    $display("=====================================================");
    $display("Casos verificados : %0d", total_casos);
    $display("Errores            : %0d", errores);
    if (errores == 0)
      $display("TODO OK -- calculadora_4bits paso la prueba DEFINITIVA");
    else
      $display("*** %0d casos con fallas -- revisar arriba ***", errores);
    $display("=====================================================");
    $finish;
  end

endmodule
