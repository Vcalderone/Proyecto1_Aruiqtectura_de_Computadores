//=====================================================================
// alu.v -- ALU combinacional de 4 bits, complemento a dos, 6 operaciones
// Solo primitivas de compuerta: and, or, not, xor, nand, nor, xnor, buf
//
//   op = 000   reinicio        r = 0000
//   op = 001   suma            r = a + b
//   op = 010   resta           r = a - b
//   op = 011   resta inversa   r = b - a
//   op = 100   shift left      r = a << b[1:0]   (logico)
//   op = 101   shift right     r = a >> b[1:0]   (logico)
//   op = 110   invalido        r = 0000
//   op = 111   invalido        r = 0000
//
// Aritmetica mod 16, sin deteccion de overflow (decision 2).
//
// Requiere: op_decoder.v, adder4.v, full_adder.v, mux2.v,
//           shift_left.v, shift_right.v
//=====================================================================

module alu (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [2:0] op,
    output wire [3:0] r
);

    //-----------------------------------------------------------------
    // Decodificacion one-hot
    // sel_rst queda sin conectar: la via de reinicio es la constante
    // 0000 (ver enmascarado, mas abajo).
    //-----------------------------------------------------------------
    wire sel_rst, sel_add, sel_sub, sel_rsub, sel_shl, sel_shr;

    op_decoder dec (
        .op       (op),
        .sel_rst  (sel_rst),
        .sel_add  (sel_add),
        .sel_sub  (sel_sub),
        .sel_rsub (sel_rsub),
        .sel_shl  (sel_shl),
        .sel_shr  (sel_shr)
    );

    //-----------------------------------------------------------------
    // Senales de control derivadas (seccion 4.5)
    //   sub  = sel_sub + sel_rsub = q2'.q1
    //   swap = sel_rsub
    //-----------------------------------------------------------------
    wire sub, swap;

    or  c0 (sub,  sel_sub, sel_rsub);
    buf c1 (swap, sel_rsub);

    //-----------------------------------------------------------------
    // Swap A/B
    //   swap = 0  ->  x = a,  y = b     (suma, resta)
    //   swap = 1  ->  x = b,  y = a     (resta inversa)
    //-----------------------------------------------------------------
    wire [3:0] x, y;

    mux2 sx0 (a[0], b[0], swap, x[0]);
    mux2 sx1 (a[1], b[1], swap, x[1]);
    mux2 sx2 (a[2], b[2], swap, x[2]);
    mux2 sx3 (a[3], b[3], swap, x[3]);

    mux2 sy0 (b[0], a[0], swap, y[0]);
    mux2 sy1 (b[1], a[1], swap, y[1]);
    mux2 sy2 (b[2], a[2], swap, y[2]);
    mux2 sy3 (b[3], a[3], swap, y[3]);

    //-----------------------------------------------------------------
    // Acondicionador de B (seccion 3.5):  yc = y XOR sub
    // El mismo 'sub' entra como carry-in del sumador y aporta el +1
    // del complemento a dos.
    //-----------------------------------------------------------------
    wire [3:0] yc;

    xor k0 (yc[0], y[0], sub);
    xor k1 (yc[1], y[1], sub);
    xor k2 (yc[2], y[2], sub);
    xor k3 (yc[3], y[3], sub);

    //-----------------------------------------------------------------
    // Sumador ripple-carry. cout se descarta -> truncamiento a 4 bits.
    //-----------------------------------------------------------------
    wire [3:0] sum;
    wire       cout;

    adder4 add (x, yc, sub, sum, cout);

    //-----------------------------------------------------------------
    // Barrel shifters. Operan sobre A directo, no sobre X: el swap solo
    // afecta la via aritmetica.
    // Solo b[1:0] controla el desplazamiento (decision 4).
    //-----------------------------------------------------------------
    wire [3:0] shl, shr;

    shift_left  sl (a, b[1:0], shl);
    shift_right sr (a, b[1:0], shr);

    //-----------------------------------------------------------------
    // Enmascarado one-hot + OR final = multiplexor de 6 vias (decision 10).
    //
    // La via de reinicio es la constante 0000 enmascarada con sel_rst:
    // 0 AND sel_rst = 0 siempre, asi que no requiere compuertas. Con
    // op = 000 las otras cinco mascaras quedan en 0 y el OR entrega 0000.
    // Lo mismo pasa con los codigos invalidos 110 y 111.
    //
    // Depende de que el decodificador sea one-hot: si dos senales se
    // activaran a la vez, el OR mezclaria resultados.
    //-----------------------------------------------------------------
    wire [3:0] m_add, m_sub, m_rsub, m_shl, m_shr;

    and ga0 (m_add[0],  sum[0], sel_add );
    and ga1 (m_add[1],  sum[1], sel_add );
    and ga2 (m_add[2],  sum[2], sel_add );
    and ga3 (m_add[3],  sum[3], sel_add );

    and gs0 (m_sub[0],  sum[0], sel_sub );
    and gs1 (m_sub[1],  sum[1], sel_sub );
    and gs2 (m_sub[2],  sum[2], sel_sub );
    and gs3 (m_sub[3],  sum[3], sel_sub );

    and gr0 (m_rsub[0], sum[0], sel_rsub);
    and gr1 (m_rsub[1], sum[1], sel_rsub);
    and gr2 (m_rsub[2], sum[2], sel_rsub);
    and gr3 (m_rsub[3], sum[3], sel_rsub);

    and gl0 (m_shl[0],  shl[0], sel_shl );
    and gl1 (m_shl[1],  shl[1], sel_shl );
    and gl2 (m_shl[2],  shl[2], sel_shl );
    and gl3 (m_shl[3],  shl[3], sel_shl );

    and gh0 (m_shr[0],  shr[0], sel_shr );
    and gh1 (m_shr[1],  shr[1], sel_shr );
    and gh2 (m_shr[2],  shr[2], sel_shr );
    and gh3 (m_shr[3],  shr[3], sel_shr );

    or  f0 (r[0], m_add[0], m_sub[0], m_rsub[0], m_shl[0], m_shr[0]);
    or  f1 (r[1], m_add[1], m_sub[1], m_rsub[1], m_shl[1], m_shr[1]);
    or  f2 (r[2], m_add[2], m_sub[2], m_rsub[2], m_shl[2], m_shr[2]);
    or  f3 (r[3], m_add[3], m_sub[3], m_rsub[3], m_shl[3], m_shr[3]);

endmodule
