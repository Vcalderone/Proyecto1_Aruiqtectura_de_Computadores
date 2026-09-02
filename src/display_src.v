//=====================================================================
// display_src.v -- Mux de fuente de display (4 bits, 4 vias)
//
// Elige que valor se muestra en los 7 segmentos segun el estado de la
// FSM. Construido jerarquicamente con instancias de mux2, igual que el
// barrel shifter: NO requiere tabla de verdad ni mapa de Karnaugh
// propio, ya estan los del mux 2:1 (secciones 3.3 y 4.3).
//
//   s1 s0   Estado   Muestra
//   -----   ------   ---------------------------------
//   0  0    S0       v_s0   <- PENDIENTE DE DECIDIR
//   0  1    S1       a      operando A
//   1  0    S2       b      operando B
//   1  1    S3       r      resultado
//
// Un 4:1 se arma con tres 2:1:
//   y = mux2( mux2(d0,d1,s0), mux2(d2,d3,s0), s1 )
//
// Compuertas: 3 mux2 x 4 bits = 12 mux2 = 48
//
// NOTA: la seccion 11 del handoff deja abierto que mostrar en S0.
// La entrada v_s0 queda expuesta para que el nivel superior decida sin
// tocar este modulo. Opciones razonables: 4'b0000 (apagado a cero) o
// {1'b0, op} para ver el numero de operacion tambien en el display.
//=====================================================================

module display_src (
    input  wire [3:0] v_s0,
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [3:0] r,
    input  wire       s1,
    input  wire       s0,
    output wire [3:0] v
);
    wire [3:0] lo;   // mux2(v_s0, a, s0)   -> estados 00 / 01
    wire [3:0] hi;   // mux2(b,    r, s0)   -> estados 10 / 11

    mux2 l0 (v_s0[0], a[0], s0, lo[0]);
    mux2 l1 (v_s0[1], a[1], s0, lo[1]);
    mux2 l2 (v_s0[2], a[2], s0, lo[2]);
    mux2 l3 (v_s0[3], a[3], s0, lo[3]);

    mux2 h0 (b[0], r[0], s0, hi[0]);
    mux2 h1 (b[1], r[1], s0, hi[1]);
    mux2 h2 (b[2], r[2], s0, hi[2]);
    mux2 h3 (b[3], r[3], s0, hi[3]);

    mux2 y0 (lo[0], hi[0], s1, v[0]);
    mux2 y1 (lo[1], hi[1], s1, v[1]);
    mux2 y2 (lo[2], hi[2], s1, v[2]);
    mux2 y3 (lo[3], hi[3], s1, v[3]);
endmodule
