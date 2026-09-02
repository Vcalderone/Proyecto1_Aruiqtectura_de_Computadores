//=====================================================================
// calculadora_4bits.v -- Envoltorio con la interfaz del testbench de
//                        la evaluacion.
//
// El testbench del profesor instancia este modulo, no 'top'. La
// diferencia es de donde vienen las entradas:
//
//   top                        calculadora_4bits
//   ---------------------      -------------------------------
//   botones + debounce         codigo, op1, op2_ext directos
//   FSM de 4 estados           'ejecutar' es la unica senal de control
//   displays de 7 segmentos    'resultado' sale crudo en 4 bits
//
// El nucleo es EL MISMO: la instancia de 'alu' y el registro de
// resultado son los de siempre. Este archivo solo saca el camino de
// datos de adentro de la maquina de estados y lo expone directo.
//
//   sel_op2 = 0  ->  segundo operando = op2_ext  (externo)
//   sel_op2 = 1  ->  segundo operando = resultado anterior
//
// La realimentacion resultado -> mux -> alu -> registro -> resultado
// NO es un lazo combinacional: el flip-flop corta el camino.
//
// Requiere: mux2.v, full_adder.v, adder4.v, shift_left.v,
//           shift_right.v, op_decoder.v, alu.v
//=====================================================================

module calculadora_4bits (
    input  wire       clk,
    input  wire       ejecutar,     // 1 = carga el resultado en el flanco
    input  wire [2:0] codigo,       // selector de operacion
    input  wire       sel_op2,      // 0 = op2_ext, 1 = resultado anterior
    input  wire [3:0] op1,          // primer operando
    input  wire [3:0] op2_ext,      // segundo operando externo
    output wire [3:0] resultado     // resultado almacenado
);

    wire [3:0] b;        // segundo operando efectivo
    wire [3:0] r_next;   // salida combinacional de la ALU
    wire [3:0] r;        // salida del registro

    //-----------------------------------------------------------------
    // Selector del segundo operando (el "selector de 1 bit" del
    // enunciado). Mismo mux2 que usa top.v.
    //-----------------------------------------------------------------
    mux2 mb0 (op2_ext[0], r[0], sel_op2, b[0]);
    mux2 mb1 (op2_ext[1], r[1], sel_op2, b[1]);
    mux2 mb2 (op2_ext[2], r[2], sel_op2, b[2]);
    mux2 mb3 (op2_ext[3], r[3], sel_op2, b[3]);

    //-----------------------------------------------------------------
    // ALU: las seis operaciones, solo compuertas.
    //-----------------------------------------------------------------
    alu core (op1, b, codigo, r_next);

    //-----------------------------------------------------------------
    // Registro de resultado. 'ejecutar' es la habilitacion de carga:
    // mientras vale 0 el registro retiene.
    //-----------------------------------------------------------------
    reg4_ini rr (clk, ejecutar, r_next, r);

    buf y0 (resultado[0], r[0]);
    buf y1 (resultado[1], r[1]);
    buf y2 (resultado[2], r[2]);
    buf y3 (resultado[3], r[3]);

endmodule


//=====================================================================
// reg4_ini.v -- Registro de 4 bits con habilitacion de carga y valor
//               inicial 0000, SIN entrada de reset.
//
// Es el reg4 de counter4.v con dos cambios, ambos obligados por la
// interfaz del testbench:
//
//   1. No hay puerto 'rst'. La interfaz que fija el enunciado de la
//      evaluacion no lo tiene, asi que el arranque limpio se resuelve
//      con el valor inicial del registro.
//
//   2. El valor inicial va en la declaracion ( reg [3:0] q = 4'b0000 ).
//      Es lo mismo que hace por.v y que el codigo de ejemplo de
//      Nandland; yosys lo sintetiza como valor de inicializacion del
//      flip-flop, y el iCE40 lo aplica al configurarse.
//
// POR QUE NO SE USA por.v ACA: por.v mantiene rst en 1 durante los
// primeros 4 flancos. El testbench ejecuta su primera operacion en el
// tercer flanco, asi que el reset todavia estaria activo y borraria
// ese primer resultado. El valor inicial no tiene ese problema.
//
//   d[i] = ejecutar·in[i] + ejecutar'·q[i]
//
// Compuertas: 4 mux2 = 16. Registros: 4
//=====================================================================

module reg4_ini (
    input  wire       clk,
    input  wire       load,
    input  wire [3:0] in,
    output wire [3:0] q_out
);
    reg  [3:0] q = 4'b0000;
    wire [3:0] d;

    mux2 x0 (q[0], in[0], load, d[0]);
    mux2 x1 (q[1], in[1], load, d[1]);
    mux2 x2 (q[2], in[2], load, d[2]);
    mux2 x3 (q[3], in[3], load, d[3]);

    always @(posedge clk)
        q <= d;

    buf y0 (q_out[0], q[0]);
    buf y1 (q_out[1], q[1]);
    buf y2 (q_out[2], q[2]);
    buf y3 (q_out[3], q[3]);
endmodule
