//=====================================================================
// shift_right.v -- Barrel shifter logico a la derecha, 0 a 3 posiciones
//
// Desplazamiento LOGICO, no aritmetico (decision 3): rellena con ceros
// por la izquierda. El signo se pierde, que es lo pedido.
//
// Requiere: mux2.v
// Compuertas: 8 muxes x 4 = 32
//=====================================================================

module shift_right (
    input  wire [3:0] a,
    input  wire [1:0] sh,
    output wire [3:0] y
);
    wire [3:0] t;

    // Etapa 1: desplaza 1 si sh[0]
    mux2 p0 (a[0], a[1], sh[0], t[0]);
    mux2 p1 (a[1], a[2], sh[0], t[1]);
    mux2 p2 (a[2], a[3], sh[0], t[2]);
    mux2 p3 (a[3], 1'b0, sh[0], t[3]);

    // Etapa 2: desplaza 2 si sh[1]
    mux2 q0 (t[0], t[2], sh[1], y[0]);
    mux2 q1 (t[1], t[3], sh[1], y[1]);
    mux2 q2 (t[2], 1'b0, sh[1], y[2]);
    mux2 q3 (t[3], 1'b0, sh[1], y[3]);
endmodule
