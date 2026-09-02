//=====================================================================
// mux2.v -- Multiplexor 2:1 de un bit
//
//   y = sel'.d0 + sel.d1
//
// SOP minima, no simplificable (seccion 4.3).
// Compuertas: 1 NOT + 2 AND + 1 OR = 4
//=====================================================================

module mux2 (
    input  wire d0,
    input  wire d1,
    input  wire sel,
    output wire y
);
    wire nsel, t0, t1;

    not n0 (nsel, sel);
    and a0 (t0,   d0, nsel);
    and a1 (t1,   d1, sel);
    or  o0 (y,    t0, t1);
endmodule
