//=====================================================================
// counter4.v -- Contador up/down de 4 bits, modulo 16
//
// Genera los operandos A y B. A diferencia de op_selector (que cuenta
// modulo 6 y necesita logica especial para la vuelta), aca el modulo 16
// es el desborde natural de 4 bits: el acarreo del bit 3 simplemente se
// descarta. Es la misma aritmetica mod 16 de la ALU.
//
// Rango en complemento a dos: 0000..0111 = 0..7, 1000..1111 = -8..-1.
// Subiendo desde 0111 se llega a 1000, o sea de +7 se pasa a -8. Es el
// comportamiento correcto: el registro guarda bits, el signo es una
// interpretacion (decision 1).
//
// CADENA DE ACARREO (subir)      CADENA DE PRESTAMO (bajar)
//   c[0]   = 1                     b[0]   = 1
//   n[i]   = q[i] XOR c[i]         n[i]   = q[i] XOR b[i]
//   c[i+1] = c[i] AND q[i]         b[i+1] = b[i] AND q[i]'
//
// El acarreo se propaga mientras el bit sea 1; el prestamo, mientras
// sea 0. Es la unica diferencia entre las dos cadenas.
//
// COMPARTIDO: con c[0] = b[0] = 1, el bit 0 queda igual en los dos
// sentidos: n[0] = q[0]'. Subir y bajar siempre invierten el bit menos
// significativo. Una sola compuerta NOT sirve para ambos, y ademas
// c[1] = q[0] y b[1] = q[0]' salen gratis.
//
// PRIORIDAD: si inc y dec llegan juntos, gana inc (igual que en
// op_selector). Sin pulsos, el valor se retiene.
//
// 'en' habilita el contador: cada contador solo responde en su propio
// estado de la FSM (A en S1, B en S2).
//
// Compuertas: 3 NOT + 6 XOR + 6 AND (cadenas)
//           + 3 AND/NOR (seleccion) + 12 AND + 4 OR (mux) + 4 AND reset
// Registros: 4
//=====================================================================

module counter4 (
    input  wire       clk,
    input  wire       rst,      // reset sincrono, deja el contador en 0000
    input  wire       en,       // habilita: solo cuenta en su estado
    input  wire       inc,      // pulso de un ciclo
    input  wire       dec,      // pulso de un ciclo
    output wire [3:0] val
);
    reg  [3:0] q;
    wire [3:0] d, m_or;
    wire [3:0] n_inc, n_dec;

    wire nq0, nq1, nq2;
    not v0 (nq0, q[0]);
    not v1 (nq1, q[1]);
    not v2 (nq2, q[2]);

    //-----------------------------------------------------------------
    // Subir: n[i] = q[i] XOR c[i] ; c[i+1] = c[i] AND q[i]
    //   c[0] = 1  ->  n[0] = q[0]' , c[1] = q[0]
    //-----------------------------------------------------------------
    wire c2, c3;

    buf ia (n_inc[0], nq0);
    xor ib (n_inc[1], q[1], q[0]);          // c[1] = q[0]
    and ic (c2,       q[0], q[1]);
    xor id (n_inc[2], q[2], c2);
    and ie (c3,       c2,   q[2]);
    xor ig (n_inc[3], q[3], c3);
    // el acarreo de salida se descarta -> modulo 16

    //-----------------------------------------------------------------
    // Bajar: n[i] = q[i] XOR b[i] ; b[i+1] = b[i] AND q[i]'
    //   b[0] = 1  ->  n[0] = q[0]' , b[1] = q[0]'
    //-----------------------------------------------------------------
    wire b2, b3;

    buf da (n_dec[0], nq0);
    xor db (n_dec[1], q[1], nq0);           // b[1] = q[0]'
    and dc (b2,       nq0,  nq1);
    xor dd (n_dec[2], q[2], b2);
    and de (b3,       b2,   nq2);
    xor dg (n_dec[3], q[3], b3);

    //-----------------------------------------------------------------
    // Seleccion: inc tiene prioridad, y todo pasa por 'en'
    //-----------------------------------------------------------------
    wire inc_ok, dec_ok, ninc, dec_raw, hold;

    and s0 (inc_ok,  en,  inc);
    not s1 (ninc,    inc);
    and s2 (dec_raw, dec, ninc);
    and s3 (dec_ok,  en,  dec_raw);
    nor s4 (hold,    inc_ok, dec_ok);

    //-----------------------------------------------------------------
    // Mux de tres vias por bit (mismo patron que op_selector)
    //-----------------------------------------------------------------
    wire [3:0] m_inc, m_dec, m_hold;

    and g00 (m_inc[0],  n_inc[0], inc_ok);
    and g01 (m_dec[0],  n_dec[0], dec_ok);
    and g02 (m_hold[0], q[0],     hold);
    or  g03 (m_or[0],   m_inc[0], m_dec[0], m_hold[0]);

    and g10 (m_inc[1],  n_inc[1], inc_ok);
    and g11 (m_dec[1],  n_dec[1], dec_ok);
    and g12 (m_hold[1], q[1],     hold);
    or  g13 (m_or[1],   m_inc[1], m_dec[1], m_hold[1]);

    and g20 (m_inc[2],  n_inc[2], inc_ok);
    and g21 (m_dec[2],  n_dec[2], dec_ok);
    and g22 (m_hold[2], q[2],     hold);
    or  g23 (m_or[2],   m_inc[2], m_dec[2], m_hold[2]);

    and g30 (m_inc[3],  n_inc[3], inc_ok);
    and g31 (m_dec[3],  n_dec[3], dec_ok);
    and g32 (m_hold[3], q[3],     hold);
    or  g33 (m_or[3],   m_inc[3], m_dec[3], m_hold[3]);

    //-----------------------------------------------------------------
    // Reset sincrono
    //-----------------------------------------------------------------
    wire nrst;
    not r0 (nrst, rst);
    and r1 (d[0], m_or[0], nrst);
    and r2 (d[1], m_or[1], nrst);
    and r3 (d[2], m_or[2], nrst);
    and r4 (d[3], m_or[3], nrst);

    always @(posedge clk)
        q <= d;

    buf y0 (val[0], q[0]);
    buf y1 (val[1], q[1]);
    buf y2 (val[2], q[2]);
    buf y3 (val[3], q[3]);
endmodule


//=====================================================================
// reg4.v -- Registro de 4 bits con habilitacion de carga
//
// Guarda el resultado R. Se carga cuando 'load' vale 1; si no, retiene.
// Cada bit es un mux 2:1 delante del flip-flop, que es el patron que ya
// se usa en op_selector y en el debounce.
//
//   d[i] = load·in[i] + load'·q[i]
//
// La salida realimenta el mux de B (usar resultado anterior). Eso NO es
// un lazo combinacional: el flip-flop corta el camino.
//
// Compuertas: 4 mux2 (16) + 4 AND de reset + 1 NOT = 21. Registros: 4
//=====================================================================

module reg4 (
    input  wire       clk,
    input  wire       rst,
    input  wire       load,
    input  wire [3:0] in,
    output wire [3:0] q_out
);
    reg  [3:0] q;
    wire [3:0] m, d;

    mux2 x0 (q[0], in[0], load, m[0]);
    mux2 x1 (q[1], in[1], load, m[1]);
    mux2 x2 (q[2], in[2], load, m[2]);
    mux2 x3 (q[3], in[3], load, m[3]);

    wire nrst;
    not r0 (nrst, rst);
    and r1 (d[0], m[0], nrst);
    and r2 (d[1], m[1], nrst);
    and r3 (d[2], m[2], nrst);
    and r4 (d[3], m[3], nrst);

    always @(posedge clk)
        q <= d;

    buf y0 (q_out[0], q[0]);
    buf y1 (q_out[1], q[1]);
    buf y2 (q_out[2], q[2]);
    buf y3 (q_out[3], q[3]);
endmodule
