//=====================================================================
// prescaler.v -- Divisor de frecuencia: genera un tick lento
//
// Contador binario libre de 15 bits. La salida 'tick' es el acarreo de
// salida del contador: vale 1 durante UN solo ciclo de reloj, cada
// 2^15 = 32768 ciclos.
//
//   25 MHz / 32768 = 763 Hz  ->  un tick cada 1,31 ms
//
// Se comparte entre los cuatro botones: un solo contador en vez de
// cuatro. Cada debounce necesita 3 ticks para aceptar un cambio, o sea
// 3,93 ms de estabilidad. El rebote tipico de un pulsador dura menos de
// 1 ms y una pulsacion humana dura mas de 50 ms, asi que el margen
// sobra por los dos lados.
//
// CONTADOR BINARIO A NIVEL DE COMPUERTA
// La cadena de acarreo es la misma idea del sumador ripple-carry, pero
// con el sumando fijo en 1:
//
//   c[0]   = 1                (siempre incrementa)
//   n[i]   = q[i] XOR c[i]
//   c[i+1] = c[i] AND q[i]
//
// Con c[0] = 1 el bit 0 se reduce a n[0] = q[0]' y c[1] = q[0], asi que
// esas dos compuertas se ahorran.
//
// tick = c[15] = AND de los 15 bits: vale 1 solo cuando el contador
// esta en todos unos, o sea el ciclo justo antes de dar la vuelta.
// No hace falta comparador ni '==': el acarreo ya es esa comparacion.
//
// Compuertas: 1 NOT + 14 XOR + 14 AND + 15 AND de reset = 44, y 15 FF
//=====================================================================

module prescaler (
    input  wire clk,
    input  wire rst,      // reset sincrono
    output wire tick
);
    reg  [14:0] q;
    wire [14:0] n;        // proximo valor del contador
    wire [14:0] d;        // n con el reset aplicado
    wire [15:1] c;        // cadena de acarreo

    //-----------------------------------------------------------------
    // Bit 0: caso reducido, c[0] = 1
    //   n[0] = q[0]'      c[1] = q[0]
    //-----------------------------------------------------------------
    not  t0 (n[0], q[0]);
    buf  k0 (c[1], q[0]);

    //-----------------------------------------------------------------
    // Bits 1..14: n[i] = q[i] XOR c[i] ; c[i+1] = c[i] AND q[i]
    //-----------------------------------------------------------------
    xor  t1  (n[1],  q[1],  c[1]);    and k1  (c[2],  c[1],  q[1]);
    xor  t2  (n[2],  q[2],  c[2]);    and k2  (c[3],  c[2],  q[2]);
    xor  t3  (n[3],  q[3],  c[3]);    and k3  (c[4],  c[3],  q[3]);
    xor  t4  (n[4],  q[4],  c[4]);    and k4  (c[5],  c[4],  q[4]);
    xor  t5  (n[5],  q[5],  c[5]);    and k5  (c[6],  c[5],  q[5]);
    xor  t6  (n[6],  q[6],  c[6]);    and k6  (c[7],  c[6],  q[6]);
    xor  t7  (n[7],  q[7],  c[7]);    and k7  (c[8],  c[7],  q[7]);
    xor  t8  (n[8],  q[8],  c[8]);    and k8  (c[9],  c[8],  q[8]);
    xor  t9  (n[9],  q[9],  c[9]);    and k9  (c[10], c[9],  q[9]);
    xor  t10 (n[10], q[10], c[10]);   and k10 (c[11], c[10], q[10]);
    xor  t11 (n[11], q[11], c[11]);   and k11 (c[12], c[11], q[11]);
    xor  t12 (n[12], q[12], c[12]);   and k12 (c[13], c[12], q[12]);
    xor  t13 (n[13], q[13], c[13]);   and k13 (c[14], c[13], q[13]);
    xor  t14 (n[14], q[14], c[14]);   and k14 (c[15], c[14], q[14]);

    //-----------------------------------------------------------------
    // tick = acarreo de salida = contador en todos unos
    //-----------------------------------------------------------------
    buf  tk (tick, c[15]);

    //-----------------------------------------------------------------
    // Reset sincrono: fuerza 0
    //-----------------------------------------------------------------
    wire nrst;
    not  r (nrst, rst);

    and  r0  (d[0],  n[0],  nrst);    and r1  (d[1],  n[1],  nrst);
    and  r2  (d[2],  n[2],  nrst);    and r3  (d[3],  n[3],  nrst);
    and  r4  (d[4],  n[4],  nrst);    and r5  (d[5],  n[5],  nrst);
    and  r6  (d[6],  n[6],  nrst);    and r7  (d[7],  n[7],  nrst);
    and  r8  (d[8],  n[8],  nrst);    and r9  (d[9],  n[9],  nrst);
    and  r10 (d[10], n[10], nrst);    and r11 (d[11], n[11], nrst);
    and  r12 (d[12], n[12], nrst);    and r13 (d[13], n[13], nrst);
    and  r14 (d[14], n[14], nrst);

    //-----------------------------------------------------------------
    // Registro: lo unico secuencial
    //-----------------------------------------------------------------
    always @(posedge clk)
        q <= d;

endmodule
