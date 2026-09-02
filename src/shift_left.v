//=====================================================================
// shift_left.v -- Barrel shifter logico a la izquierda, 0 a 3 posiciones
//
// Dos etapas en cascada: sh[0] desplaza 1, sh[1] desplaza 2.
// Rellena con ceros por la derecha.
//
// No lleva mapa de Karnaugh propio (decision 9): 6 entradas = 64 filas.
// Se documenta por descomposicion jerarquica en muxes 2:1.
//
// Requiere: mux2.v
// Compuertas: 8 muxes x 4 = 32 (los 3 con constante 0 se reducen
//             a un AND cada uno en sintesis)
//=====================================================================

module shift_left (
    input  wire [3:0] a,
    input  wire [1:0] sh,
    output wire [3:0] y
);
    wire [3:0] t;   // salida de la etapa de 1 posicion

    // Etapa 1: desplaza 1 si sh[0]
    mux2 p3 (a[3], a[2], sh[0], t[3]);
    mux2 p2 (a[2], a[1], sh[0], t[2]);
    mux2 p1 (a[1], a[0], sh[0], t[1]);
    mux2 p0 (a[0], 1'b0, sh[0], t[0]);

    // Etapa 2: desplaza 2 si sh[1]
    mux2 q3 (t[3], t[1], sh[1], y[3]);
    mux2 q2 (t[2], t[0], sh[1], y[2]);
    mux2 q1 (t[1], 1'b0, sh[1], y[1]);
    mux2 q0 (t[0], 1'b0, sh[1], y[0]);
endmodule
