//=====================================================================
// dash_s0.v -- Guion en los dos displays durante S0
//
// En S0 se ingresa la operacion, que se muestra en los LEDs. Los dos
// displays de 7 segmentos muestran un guion (solo el segmento g), como
// una linea horizontal:
//
//        [ - ][ - ]
//
// Se eligio el guion en vez de apagarlos porque apagados se confunden
// con "no arranco", y un 0 se confunde con un valor real. Dos guiones
// no se confunden con nada, y de paso confirman que los dos displays
// estan vivos antes de empezar.
//
// El display izquierdo ya tiene a..f en 0 siempre (solo usa g), asi
// que basta forzar su g. El derecho necesita apagar a..f y forzar g.
//
//   izq_g = signo   OR  en_op
//   der_x = der_x  AND  en_op'      para x en a..f
//   der_g = der_g   OR  en_op
//
// Compuertas: 6 AND + 2 OR + 1 NOT = 9
//
// Formato del bus: seg[6:0] = {a,b,c,d,e,f,g}
//=====================================================================

module dash_s0 (
    input  wire       en_op,        // 1 en el estado S0
    input  wire [6:0] izq_in,
    input  wire [6:0] der_in,
    output wire [6:0] izq_out,
    output wire [6:0] der_out
);
    wire n_en;
    not v (n_en, en_op);

    //-----------------------------------------------------------------
    // Display izquierdo: a..f ya vienen en 0, solo se fuerza g
    //-----------------------------------------------------------------
    buf ia (izq_out[6], izq_in[6]);
    buf ib (izq_out[5], izq_in[5]);
    buf ic (izq_out[4], izq_in[4]);
    buf id (izq_out[3], izq_in[3]);
    buf ie (izq_out[2], izq_in[2]);
    buf if_ (izq_out[1], izq_in[1]);
    or  ig (izq_out[0], izq_in[0], en_op);

    //-----------------------------------------------------------------
    // Display derecho: se apagan a..f y se fuerza g
    //-----------------------------------------------------------------
    and da (der_out[6], der_in[6], n_en);
    and db (der_out[5], der_in[5], n_en);
    and dc (der_out[4], der_in[4], n_en);
    and dd (der_out[3], der_in[3], n_en);
    and de (der_out[2], der_in[2], n_en);
    and df (der_out[1], der_in[1], n_en);
    or  dg (der_out[0], der_in[0], en_op);
endmodule


//=====================================================================
// por.v -- Power-On Reset
//
// El enunciado no pide boton de reset y los cuatro botones ya estan
// asignados. El "reinicio" del enunciado son otras dos cosas, ambas ya
// implementadas: la operacion 3'b000 (pone R en cero) y el boton
// superior derecho en S3 (vuelve a S0).
//
// Igual hace falta arrancar limpio. El iCE40 inicializa sus flip-flops
// en 0 al configurarse, pero en SIMULACION arrancan en X y sin reset
// se quedarian en X para siempre. Este bloque resuelve las dos cosas:
// mantiene rst en 1 durante los primeros 4 ciclos y despues lo suelta.
//
//   por  = 0000  al arrancar        rst = 1
//   0001, 0011, 0111, 1111          rst = 0 desde el 4to ciclo
//
// El valor inicial va en la declaracion del registro. Es lo mismo que
// hace el codigo de Nandland (reg [6:0] r_Hex_Encoding = 7'h00) y
// yosys lo sintetiza como valor de inicializacion del flip-flop.
//
// Compuertas: 4 buf + 1 NOT. Registros: 4
//=====================================================================

module por (
    input  wire clk,
    output wire rst
);
    reg  [3:0] q = 4'b0000;
    wire [3:0] d;

    buf b0 (d[0], 1'b1);
    buf b1 (d[1], q[0]);
    buf b2 (d[2], q[1]);
    buf b3 (d[3], q[2]);

    always @(posedge clk)
        q <= d;

    not n0 (rst, q[3]);
endmodule
