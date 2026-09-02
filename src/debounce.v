//=====================================================================
// debounce.v -- Filtro de rebote por muestreo, deteccion de flanco
//               y modulo 'boton' que junta los dos.
//
// Solo primitivas de compuerta. Lo unico secuencial son los registros
// (q <= d), con la logica de proximo estado construida afuera.
//=====================================================================


//---------------------------------------------------------------------
// debounce -- acepta un cambio solo tras 3 muestras seguidas iguales
//
// El muestreo lo marca 'tick', que viene del prescaler compartido
// (1,31 ms). El registro de desplazamiento avanza SOLO cuando tick=1;
// el resto de los ciclos retiene, usando un mux 2:1 por bit.
//
//   sr[2:0] = las tres ultimas muestras de 'raw'
//
//   set = sr2 AND sr1 AND sr0     las tres dicen 1 -> aceptar 1
//   clr = sr2 NOR sr1 NOR sr0     las tres dicen 0 -> aceptar 0
//   d_clean = set OR (clean AND clr')      si no, retiene
//
// Un rebote hace que las tres muestras no coincidan, asi que 'clean'
// no se mueve. Se necesitan 3 ticks = 3,93 ms de estabilidad.
//
// POLARIDAD: este modulo asume boton ACTIVO EN ALTO (apretado = 1).
// Si la Go Board resulta activa en bajo, se invierte 'raw' con una
// compuerta NOT en el nivel superior, sin tocar este modulo.
//
// Compuertas: 3 mux2 (12) + AND3 + OR3 + AND + OR + NOT reset = 17
// Registros: 4 (sr[2:0] + clean)
//---------------------------------------------------------------------
module debounce (
    input  wire clk,
    input  wire rst,
    input  wire tick,     // pulso de muestreo del prescaler
    input  wire raw,      // entrada cruda del boton
    output wire clean     // nivel filtrado
);
    reg  [2:0] sr;
    reg        cl;

    wire [2:0] sr_n, sr_d;
    wire       cl_n, cl_d;

    //-----------------------------------------------------------------
    // Registro de desplazamiento con habilitacion por tick.
    // Cada bit pasa por un mux 2:1: con tick=0 se retiene.
    //-----------------------------------------------------------------
    mux2 m0 (sr[0], raw,   tick, sr_n[0]);
    mux2 m1 (sr[1], sr[0], tick, sr_n[1]);
    mux2 m2 (sr[2], sr[1], tick, sr_n[2]);

    //-----------------------------------------------------------------
    // Aceptacion por mayoria unanime
    //-----------------------------------------------------------------
    wire set, nclr, hold;

    and  a0 (set,  sr[2], sr[1], sr[0]);   // las tres en 1
    or   o0 (nclr, sr[2], sr[1], sr[0]);   // alguna en 1  (= clr')
    and  a1 (hold, cl,    nclr);           // retiene mientras no sean 000
    or   o1 (cl_n, set,   hold);

    //-----------------------------------------------------------------
    // Reset sincrono
    //-----------------------------------------------------------------
    wire nrst;
    not  r  (nrst, rst);

    and  r0 (sr_d[0], sr_n[0], nrst);
    and  r1 (sr_d[1], sr_n[1], nrst);
    and  r2 (sr_d[2], sr_n[2], nrst);
    and  r3 (cl_d,    cl_n,    nrst);

    //-----------------------------------------------------------------
    always @(posedge clk) begin
        sr <= sr_d;
        cl <= cl_d;
    end

    buf  y (clean, cl);
endmodule


//---------------------------------------------------------------------
// edge_detect -- pulso de UN ciclo en el flanco de subida
//
//   prev  <= nivel
//   pulso  = nivel AND prev'
//
// Esto es lo que convierte "boton apretado" (nivel, dura miles de
// ciclos) en "boton recien apretado" (pulso, dura 1 ciclo). Sin esto
// los contadores incrementarian miles de veces por apreton y la FSM
// recorreria los cuatro estados en cuatro ciclos.
//
// Compuertas: 2 (NOT + AND) + 1 de reset. Registros: 1
//---------------------------------------------------------------------
module edge_detect (
    input  wire clk,
    input  wire rst,
    input  wire nivel,
    output wire pulso
);
    reg  prev;
    wire nprev, prev_d, nrst;

    not  r  (nrst,   rst);
    and  r0 (prev_d, nivel, nrst);

    always @(posedge clk)
        prev <= prev_d;

    not  n0 (nprev, prev);
    and  a0 (pulso, nivel, nprev);
endmodule


//---------------------------------------------------------------------
// boton -- debounce + deteccion de flanco
//
// Entrega las dos cosas:
//   nivel  el estado filtrado, util para depurar o encender un LED
//   pulso  un ciclo de reloj en el flanco de subida, que es lo que
//          consumen la FSM y los contadores
//
// Compuertas: 20. Registros: 5
//---------------------------------------------------------------------
module boton (
    input  wire clk,
    input  wire rst,
    input  wire tick,
    input  wire raw,
    output wire nivel,
    output wire pulso
);
    debounce    db (clk, rst, tick, raw, nivel);
    edge_detect ed (clk, rst, nivel, pulso);
endmodule
