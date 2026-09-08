`timescale 1ns/1ps
//=====================================================================
// calculadora_4bits_tb_supremo.sv -- prueba exhaustiva de la interfaz
//   de evaluacion (calculadora_4bits): barrido completo de los 8
//   codigos x 16 x 16 valores de A y B (2048 casos, sel_op2=0), mas
//   pruebas dirigidas de retencion, reinicio y encadenamiento via
//   sel_op2=1 (realimentacion del resultado anterior).
//
// No aborta al primer fallo: cuenta errores y solo imprime el detalle
// de los casos que fallan, para poder ver el panorama completo.
//=====================================================================

module calculadora_4bits_tb_supremo;

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

  integer total_casos;
  integer errores;
  integer codigo_i, a_i, b_i;

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

  task automatic probar_directo(input [2:0] cod, input [3:0] a, input [3:0] b, input string nombre);
    logic [3:0] esperado;
    begin
      esperado = esperado_calc(cod, a, b);
      codigo   = cod;
      sel_op2  = 1'b0;
      op1      = a;
      op2_ext  = b;
      pulso_ejecutar();
      total_casos = total_casos + 1;
      if (resultado !== esperado) begin
        errores = errores + 1;
        $display("FAIL %s: codigo=%b op1=%b op2_ext=%b esperado=%b obtenido=%b",
                  nombre, cod, a, b, esperado, resultado);
      end
    end
  endtask

  task automatic probar_encadenado(input [2:0] cod, input [3:0] a, input [3:0] esperado, input string nombre);
    begin
      codigo  = cod;
      sel_op2 = 1'b1;
      op1     = a;
      pulso_ejecutar();
      total_casos = total_casos + 1;
      if (resultado !== esperado) begin
        errores = errores + 1;
        $display("FAIL %s: codigo=%b op1=%b (op2=resultado anterior) esperado=%b obtenido=%b",
                  nombre, cod, a, esperado, resultado);
      end else begin
        $display("PASS %s: resultado=%b", nombre, resultado);
      end
    end
  endtask

  task automatic probar_reset(input [3:0] a_prev, input [3:0] b_prev);
    begin
      codigo = SUMA; sel_op2 = 1'b0; op1 = a_prev; op2_ext = b_prev; pulso_ejecutar();
      codigo = RST;  sel_op2 = 1'b0; op1 = a_prev; op2_ext = b_prev; pulso_ejecutar();
      total_casos = total_casos + 1;
      if (resultado !== 4'b0000) begin
        errores = errores + 1;
        $display("FAIL reinicio: tras codigo=000 resultado=%b (esperado 0000)", resultado);
      end else begin
        $display("PASS reinicio: resultado vuelve a 0000 tras codigo=000");
      end
    end
  endtask

  task automatic probar_retencion;
    logic [3:0] valor_previo;
    begin
      codigo = SUMA; sel_op2 = 1'b0; op1 = 4'b0011; op2_ext = 4'b0010;
      pulso_ejecutar();
      valor_previo = resultado;
      ejecutar = 1'b0;
      repeat (5) @(posedge clk);
      total_casos = total_casos + 1;
      if (resultado !== valor_previo) begin
        errores = errores + 1;
        $display("FAIL retencion: resultado cambio sin ejecutar, de %b a %b", valor_previo, resultado);
      end else begin
        $display("PASS retencion: resultado se mantuvo en %b sin pulsos de ejecutar", valor_previo);
      end
    end
  endtask

  initial begin
    $dumpfile("calculadora_4bits_tb_supremo.vcd");
    $dumpvars(0, calculadora_4bits_tb_supremo);

    clk = 1'b0; ejecutar = 1'b0; codigo = 3'b000; sel_op2 = 1'b0;
    op1 = 4'b0000; op2_ext = 4'b0000;
    total_casos = 0; errores = 0;
    repeat (2) @(posedge clk);

    $display("=====================================================");
    $display("1. Barrido exhaustivo: 8 codigos x 16 x 16 (2048 casos)");
    $display("=====================================================");
    for (codigo_i = 0; codigo_i < 8; codigo_i = codigo_i + 1) begin
      for (a_i = 0; a_i < 16; a_i = a_i + 1) begin
        for (b_i = 0; b_i < 16; b_i = b_i + 1) begin
          probar_directo(codigo_i[2:0], a_i[3:0], b_i[3:0],
                          $sformatf("cod=%0d a=%0d b=%0d", codigo_i, a_i, b_i));
        end
      end
      $display("  ... codigo %0d completo (%0d casos acumulados, %0d errores)",
                codigo_i, total_casos, errores);
    end

    $display("=====================================================");
    $display("2. Reinicio (codigo=000)");
    $display("=====================================================");
    probar_reset(4'b0111, 4'b0011);
    probar_reset(4'b1000, 4'b1000);

    $display("=====================================================");
    $display("3. Retencion sin pulso de ejecutar");
    $display("=====================================================");
    probar_retencion;

    $display("=====================================================");
    $display("4. Encadenamiento con sel_op2=1 (realimentacion de R)");
    $display("=====================================================");
    probar_directo(SUMA, 4'b0011, 4'b0100, "base: 3 + 4 = 7");
    probar_encadenado(RESTA, 4'b0010, 4'b1011, "2 - R(7) = -5");
    probar_encadenado(SHL,   4'b0001, 4'b1000, "1 << R[1:0](3) = 8");
    probar_encadenado(RINV,  4'b0101, 4'b0011, "R(8) - 5 = 3");
    probar_encadenado(SHR,   4'b1111, 4'b0001, "15 >> R[1:0](3) = 1");

    $display("=====================================================");
    $display("Casos verificados : %0d", total_casos);
    $display("Errores            : %0d", errores);
    if (errores == 0)
      $display("TODO OK -- calculadora_4bits paso la prueba SUPREMA");
    else
      $display("*** %0d casos con fallas -- revisar arriba ***", errores);
    $display("=====================================================");
    $finish;
  end

endmodule
