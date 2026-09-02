//=====================================================================
// op_decoder.v -- Decodificador de operacion one-hot (3 bits -> 6 lineas)
//
// Cada salida es un minterminio completo de 3 literales (seccion 4.4).
// Los don't-cares 110 y 111 NO se aprovechan (decision 7): con las
// expresiones completas, un codigo invalido deja las seis salidas en 0
// y la ALU entrega R = 0000. Comportamiento seguro deliberado.
//
// Los tres inversores se calculan una vez y se comparten.
//
// Compuertas: 3 NOT + 6 AND de 3 entradas = 9
//=====================================================================

module op_decoder (
    input  wire [2:0] op,
    output wire       sel_rst,
    output wire       sel_add,
    output wire       sel_sub,
    output wire       sel_rsub,
    output wire       sel_shl,
    output wire       sel_shr
);
    wire n2, n1, n0;

    not v2 (n2, op[2]);
    not v1 (n1, op[1]);
    not v0 (n0, op[0]);

    and d0 (sel_rst,  n2,    n1,    n0   );   // 000  q2'q1'q0'
    and d1 (sel_add,  n2,    n1,    op[0]);   // 001  q2'q1'q0
    and d2 (sel_sub,  n2,    op[1], n0   );   // 010  q2'q1 q0'
    and d3 (sel_rsub, n2,    op[1], op[0]);   // 011  q2'q1 q0
    and d4 (sel_shl,  op[2], n1,    n0   );   // 100  q2 q1'q0'
    and d5 (sel_shr,  op[2], n1,    op[0]);   // 101  q2 q1'q0
endmodule
