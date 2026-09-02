//=====================================================================
// fsm_control.v -- Maquina de estados de control (seccion 9)
//
// Cuatro estados, codificacion binaria de 2 bits (decision 14):
//
//   s1 s0   Estado   Se ingresa        Se muestra
//   -----   ------   ---------------   ----------------
//   0  0    S0       codigo de op      LEDs
//   0  1    S1       operando A        7 segmentos
//   1  0    S2       operando B        7 segmentos
//   1  1    S3       --                7 segmentos (R)
//
// Con esta codificacion la secuencia S0->S1->S2->S3->S0 es exactamente
// un contador binario de 2 bits, y la logica de proximo estado se
// reduce a dos compuertas:
//
//   n1 = s1 XOR s0
//   n0 = s0'
//
// AVANCE. Se avanza con 'confirmar' desde cualquier estado, y ademas
// con 'usar_anterior' solo estando en S2:
//
//   en_s2   = s1 AND s0'                    detecta el estado S2 (10)
//   sel_op2 = usar_anterior AND en_s2
//   avanzar = confirmar OR sel_op2
//
// sel_op2 ES COMBINACIONAL, NO REGISTRADO. Si se capturara en un
// flip-flop, en el flanco en que se carga R todavia valdria 0 y el mux
// de B entregaria op2 en vez de R. Dura solo el ciclo del pulso, que es
// justo el que importa.
//
// CARGA DEL RESULTADO. El registro R se carga al salir de S2, con
// cualquiera de los dos caminos:
//
//   load_R = en_s2 AND (confirmar OR usar_anterior)
//
// RETENCION. Sin pulso el estado se mantiene: cada bit pasa por un mux
// de dos vias, igual que en op_selector.
//
//   d1 = avanzar·n1 + avanzar'·s1
//   d0 = avanzar·n0 + avanzar'·s0
//
// DECODIFICACION DE ESTADO. Las cuatro salidas en_* son one-hot y
// habilitan cada bloque en su propio estado: en_op al op_selector,
// en_A al contador de A, en_B al de B. Sin esto los tres reaccionarian
// a los mismos botones al mismo tiempo.
//
// Compuertas: 2 NOT + 2 mux2 + ~10 = 24. Registros: 2
//=====================================================================

module fsm_control (
    input  wire clk,
    input  wire rst,
    input  wire confirmar,       // pulso, boton superior derecho
    input  wire usar_anterior,   // pulso, boton inferior derecho
    output wire s1,
    output wire s0,
    output wire en_op,           // S0: habilita el selector de operacion
    output wire en_A,            // S1: habilita el contador de A
    output wire en_B,            // S2: habilita el contador de B
    output wire en_R,            // S3: mostrando resultado
    output wire sel_op2,         // 1 = el mux de B toma R
    output wire load_R           // carga el registro de resultado
);
    reg  q1, q0;
    wire n1, n0;
    wire ns1, ns0;

    not v1 (ns1, q1);
    not v0 (ns0, q0);

    //-----------------------------------------------------------------
    // Decodificacion de estado (one-hot)
    //-----------------------------------------------------------------
    and e0 (en_op, ns1, ns0);    // 00
    and e1 (en_A,  ns1, q0 );    // 01
    and e2 (en_B,  q1,  ns0);    // 10
    and e3 (en_R,  q1,  q0 );    // 11

    //-----------------------------------------------------------------
    // Control: en_B ya es la deteccion de S2, se reutiliza
    //-----------------------------------------------------------------
    wire any_conf, avanzar;

    and c0 (sel_op2,  usar_anterior, en_B);
    or  c1 (any_conf, confirmar,     usar_anterior);
    and c2 (load_R,   en_B,          any_conf);
    or  c3 (avanzar,  confirmar,     sel_op2);

    //-----------------------------------------------------------------
    // Proximo estado: contador binario de 2 bits
    //-----------------------------------------------------------------
    xor p1 (n1, q1, q0);
    buf p0 (n0, ns0);

    //-----------------------------------------------------------------
    // Retencion: mux de dos vias por bit
    //-----------------------------------------------------------------
    wire m1, m0, d1, d0;

    mux2 h1 (q1, n1, avanzar, m1);
    mux2 h0 (q0, n0, avanzar, m0);

    wire nrst;
    not r0 (nrst, rst);
    and r1 (d1, m1, nrst);
    and r2 (d0, m0, nrst);

    always @(posedge clk) begin
        q1 <= d1;
        q0 <= d0;
    end

    buf y1 (s1, q1);
    buf y0 (s0, q0);
endmodule
