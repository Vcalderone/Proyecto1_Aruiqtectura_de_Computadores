//=====================================================================
// seg7_decoder.v -- Decodificador de 7 segmentos (seccion 4.8)
//
// Entrada: D[3:0], magnitud, solo valores 0..8.
// Salida:  seg[6:0] = {a,b,c,d,e,f,g}, LOGICA POSITIVA (1 = encendido).
//
// Ecuaciones SOP minimas obtenidas por K-map aprovechando los
// don't-care 9..15 (decision 6):
//
//   a = D2'D0' + D1 + D2D0
//   b = D2'    + D1'D0' + D1D0
//   c = D1'    + D0 + D2
//   d = D2'D0' + D2'D1 + D1D0' + D2D1'D0
//   e = D0'(D2' + D1)                        [factorizada, 3 literales]
//   f = D1'D0' + D2D1' + D2D0'
//   g = D2'D1  + D2D1' + D2D0' + D3
//
// D3 aparece en una sola expresion (g). El 8 (1000) enciende los mismos
// segmentos a..f que el 0 (0000), asi que ambos se agrupan y el grupo
// cruza las dos mitades del mapa, eliminando D3. En 'g' no se puede
// porque el 0 tiene g=0 y el 8 tiene g=1.
//
// TERMINOS COMPARTIDOS: seis productos se usan en mas de un segmento y
// se calculan una sola vez.
//
//   p_n2n0 = D2'D0'    -> a, d
//   p_n1n0 = D1'D0'    -> b, f
//   p_n2d1 = D2'D1     -> d, g
//   p_d2n1 = D2 D1'    -> f, g
//   p_d2n0 = D2 D0'    -> f, g
//
// Compuertas: 3 NOT + 10 AND + 7 OR = 20
// (el handoff estimaba ~30; el compartir baja el conteo a 20)
//
// Si el display resulta activo en bajo, se cambia la compuerta de
// salida de cada segmento de OR a NOR por De Morgan, sin rehacer
// ningun K-map (decision 11).
//=====================================================================

module seg7_decoder (
    input  wire [3:0] d_in,
    output wire [6:0] seg      // {a,b,c,d,e,f,g}
);
    wire D3, D2, D1, D0;
    buf b3 (D3, d_in[3]);
    buf b2 (D2, d_in[2]);
    buf b1 (D1, d_in[1]);
    buf b0 (D0, d_in[0]);

    wire n2, n1, n0;
    not v2 (n2, D2);
    not v1 (n1, D1);
    not v0 (n0, D0);

    //-----------------------------------------------------------------
    // Productos compartidos
    //-----------------------------------------------------------------
    wire p_n2n0, p_n1n0, p_n2d1, p_d2n1, p_d2n0;

    and q0 (p_n2n0, n2, n0);      // D2'D0'   -> a, d
    and q1 (p_n1n0, n1, n0);      // D1'D0'   -> b, f
    and q2 (p_n2d1, n2, D1);      // D2'D1    -> d, g
    and q3 (p_d2n1, D2, n1);      // D2 D1'   -> f, g
    and q4 (p_d2n0, D2, n0);      // D2 D0'   -> f, g

    //-----------------------------------------------------------------
    // Productos de un solo uso
    //-----------------------------------------------------------------
    wire p_d2d0, p_d1d0, p_d1n0, p_d2n1d0;

    and q5 (p_d2d0,   D2, D0);         // D2 D0
    and q6 (p_d1d0,   D1, D0);         // D1 D0
    and q7 (p_d1n0,   D1, n0);         // D1 D0'
    and q8 (p_d2n1d0, D2, n1, D0);     // D2 D1'D0

    //-----------------------------------------------------------------
    // Segmento a = D2'D0' + D1 + D2D0
    //-----------------------------------------------------------------
    or  sa (seg[6], p_n2n0, D1, p_d2d0);

    //-----------------------------------------------------------------
    // Segmento b = D2' + D1'D0' + D1D0
    //-----------------------------------------------------------------
    or  sb (seg[5], n2, p_n1n0, p_d1d0);

    //-----------------------------------------------------------------
    // Segmento c = D1' + D0 + D2
    //-----------------------------------------------------------------
    or  sc (seg[4], n1, D0, D2);

    //-----------------------------------------------------------------
    // Segmento d = D2'D0' + D2'D1 + D1D0' + D2D1'D0
    //-----------------------------------------------------------------
    or  sd (seg[3], p_n2n0, p_n2d1, p_d1n0, p_d2n1d0);

    //-----------------------------------------------------------------
    // Segmento e = D0'(D2' + D1)
    //-----------------------------------------------------------------
    wire e_or;
    or  q9 (e_or,   n2, D1);
    and se (seg[2], n0, e_or);

    //-----------------------------------------------------------------
    // Segmento f = D1'D0' + D2D1' + D2D0'
    //-----------------------------------------------------------------
    or  sf (seg[1], p_n1n0, p_d2n1, p_d2n0);

    //-----------------------------------------------------------------
    // Segmento g = D2'D1 + D2D1' + D2D0' + D3
    //-----------------------------------------------------------------
    or  sg (seg[0], p_n2d1, p_d2n1, p_d2n0, D3);

endmodule


//=====================================================================
// seg7_signo.v -- Display izquierdo: solo el segmento g (el guion)
//
//   g    = signo
//   a..f = 0
//
// Conexion directa, sin logica. Se deja como modulo para que el nivel
// superior quede simetrico con el display derecho.
//=====================================================================

module seg7_signo (
    input  wire       signo,
    output wire [6:0] seg      // {a,b,c,d,e,f,g}
);
    buf za (seg[6], 1'b0);
    buf zb (seg[5], 1'b0);
    buf zc (seg[4], 1'b0);
    buf zd (seg[3], 1'b0);
    buf ze (seg[2], 1'b0);
    buf zf (seg[1], 1'b0);
    buf gg (seg[0], signo);
endmodule
