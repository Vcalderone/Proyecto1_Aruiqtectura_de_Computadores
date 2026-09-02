//=====================================================================
// op_selector.v -- Contador up/down modulo 6, rango 000..101
//
// Selecciona el codigo de operacion con los botones superior e inferior
// izquierdos. Logica de proximo estado con primitivas de compuerta;
// los flip-flops son el unico bloque secuencial.
//
// NOTA DE CONSISTENCIA (seccion 4.2 del handoff): este codigo NO usa
// exactamente las expresiones minimas del informe.
//
//   informe  n1 subir = q2'.(q1 XOR q0)       <- coincide
//   informe  n1 bajar = q1.q0 + q2.q0'
//   codigo   n1 bajar = q2'q1q0 + q2q1'q0'
//   informe  n2 bajar = q1'.(q2 XNOR q0)
//   codigo   n2 bajar = q2'q1'q0' + q2q1'q0
//
// Las tres formas son funcionalmente equivalentes y estan verificadas.
// Queda pendiente decidir si se unifican con el informe.
//=====================================================================

module op_selector (
    input  wire       clk,
    input  wire       rst,      // reset sincrono, deja op en 000
    input  wire       inc,      // pulso: boton superior izquierdo
    input  wire       dec,      // pulso: boton inferior izquierdo
    output wire [2:0] op
);
    reg  [2:0] q;
    wire [2:0] d;               // proximo estado
    wire [2:0] n_inc, n_dec;    // candidatos

    wire nq2, nq1, nq0;
    not v2 (nq2, q[2]);
    not v1 (nq1, q[1]);
    not v0 (nq0, q[0]);

    //-----------------------------------------------------------------
    // Incremento: 000->001->010->011->100->101->000
    //   n0 = q0'
    //   n1 = q2' AND (q1 XOR q0)
    //   n2 = (q1 AND q0) OR (q2 AND q0')
    //-----------------------------------------------------------------
    wire x10, a20, a21;

    buf  i0 (n_inc[0], nq0);
    xor  i1 (x10,      q[1], q[0]);
    and  i2 (n_inc[1], nq2,  x10);
    and  i3 (a20,      q[1], q[0]);
    and  i4 (a21,      q[2], nq0);
    or   i5 (n_inc[2], a20,  a21);

    //-----------------------------------------------------------------
    // Decremento: 000->101->100->011->010->001->000
    //   n0 = q0'
    //   n1 = (q2' AND q1 AND q0) OR (q2 AND q1' AND q0')
    //   n2 = (q2' AND q1' AND q0') OR (q2 AND q1' AND q0)
    //-----------------------------------------------------------------
    wire b10, b11, b20, b21;

    buf  e0 (n_dec[0], nq0);
    and  e1 (b10,      nq2,  q[1], q[0]);
    and  e2 (b11,      q[2], nq1,  nq0);
    or   e3 (n_dec[1], b10,  b11);
    and  e4 (b20,      nq2,  nq1,  nq0);
    and  e5 (b21,      q[2], nq1,  q[0]);
    or   e6 (n_dec[2], b20,  b21);

    //-----------------------------------------------------------------
    // Seleccion: inc tiene prioridad; sin pulso, mantiene el valor
    //-----------------------------------------------------------------
    wire ninc, dec_only, hold;

    not s0 (ninc,     inc);
    and s1 (dec_only, dec,  ninc);
    nor s2 (hold,     inc,  dec_only);

    wire [2:0] m_inc, m_dec, m_hold;
    wire [2:0] m_or;

    and g00 (m_inc[0],  n_inc[0], inc);
    and g01 (m_dec[0],  n_dec[0], dec_only);
    and g02 (m_hold[0], q[0],     hold);
    or  g03 (m_or[0],   m_inc[0], m_dec[0], m_hold[0]);

    and g10 (m_inc[1],  n_inc[1], inc);
    and g11 (m_dec[1],  n_dec[1], dec_only);
    and g12 (m_hold[1], q[1],     hold);
    or  g13 (m_or[1],   m_inc[1], m_dec[1], m_hold[1]);

    and g20 (m_inc[2],  n_inc[2], inc);
    and g21 (m_dec[2],  n_dec[2], dec_only);
    and g22 (m_hold[2], q[2],     hold);
    or  g23 (m_or[2],   m_inc[2], m_dec[2], m_hold[2]);

    // Reset sincrono: fuerza 000
    wire nrst;
    not r0 (nrst, rst);
    and r1 (d[0], m_or[0], nrst);
    and r2 (d[1], m_or[1], nrst);
    and r3 (d[2], m_or[2], nrst);

    //-----------------------------------------------------------------
    // Registro de estado -- unico bloque secuencial
    //-----------------------------------------------------------------
    always @(posedge clk)
        q <= d;

    assign op = q;
endmodule
