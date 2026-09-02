//=====================================================================
// display_chain.v -- Cadena completa de visualizacion
//
//   A ──┐
//   B ──┼─→ [display_src] ─→ V ─→ [abs4] ─┬─→ signo ─→ [seg7_signo] ─→ izq
//   R ──┤         ↑                       │
// v_s0 ─┘       s1,s0                     └─→ D ─────→ [seg7_decoder] → der
//
// El bloque de valor absoluto opera sobre V (lo que se este mostrando),
// no solo sobre R: A y B tambien son complemento a dos y tambien se
// muestran como signo + magnitud.
//
// Compuertas: 48 (display_src) + 23 (abs4) + 20 (seg7_decoder) = 91
//
// Requiere: mux2.v, full_adder.v, adder4.v, display_src.v, abs4.v,
//           seg7_decoder.v
//=====================================================================

module display_chain (
    input  wire [3:0] v_s0,      // que mostrar en S0 (pendiente de decidir)
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [3:0] r,
    input  wire       s1,
    input  wire       s0,
    output wire [3:0] v,         // valor mostrado, expuesto para simular
    output wire       signo,
    output wire [3:0] d,         // magnitud, expuesta para simular
    output wire [6:0] seg_izq,   // display izquierdo: signo
    output wire [6:0] seg_der    // display derecho: magnitud
);
    display_src  src (v_s0, a, b, r, s1, s0, v);
    abs4         av  (v, signo, d);
    seg7_decoder sd  (d, seg_der);
    seg7_signo   ss  (signo, seg_izq);
endmodule
