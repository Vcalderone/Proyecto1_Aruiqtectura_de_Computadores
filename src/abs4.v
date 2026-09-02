//=====================================================================
// abs4.v -- Valor absoluto: separa signo y magnitud (seccion 3.7)
//
//   signo = V3
//   D     = (V XOR V3) + V3
//
// Con V positivo (V3=0) el XOR no cambia nada y el carry-in es 0: D = V.
// Con V negativo (V3=1) el XOR invierte y el carry-in suma 1: D = -V,
// que es exactamente el complemento a dos.
//
// DETALLE: el bit 3 del XOR es V3 XOR V3 = 0 SIEMPRE, asi que no
// necesita compuerta. Son 3 XOR, no 4. Se ata la constante 0 directo
// en la conexion del puerto.
//
// Caso especial V = 1000 (-8): da D = 1000 = 8, el unico valor cuyo
// patron de bits no cambia, porque +8 no existe en el rango.
//
// Consecuencia: D solo toma valores 0..8. Los codigos 9..15 son
// inalcanzables -> don't-care en el decodificador de 7 segmentos.
//
// El adder4 se reutiliza como MODULO, no como instancia: esta es una
// segunda instancia, independiente de la de la ALU. Las dos son
// combinacionales y operan al mismo tiempo, asi que no se pueden
// compartir sin multiplexar las entradas (mas caro que el sumador).
//
// Compuertas: 3 XOR + adder4 (20). Con b = 0000 fijo, la sintesis
// reduce el sumador a un incrementador de ~7 compuertas.
//=====================================================================

module abs4 (
    input  wire [3:0] v,
    output wire       signo,
    output wire [3:0] d
);
    wire [2:0] x;      // V[2:0] XOR V3 ; el bit 3 es constante 0
    wire       cout;   // se descarta

    buf s (signo, v[3]);

    xor x0 (x[0], v[0], v[3]);
    xor x1 (x[1], v[1], v[3]);
    xor x2 (x[2], v[2], v[3]);

    adder4 inc ({1'b0, x[2:0]}, 4'b0000, v[3], d, cout);
endmodule
