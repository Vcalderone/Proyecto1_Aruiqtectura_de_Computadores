//=====================================================================
// full_adder.v -- Sumador completo de 1 bit
//
//   s    = a XOR b XOR cin
//   cout = (a AND b) OR ((a XOR b) AND cin)
//
// El termino (a XOR b) se calcula una sola vez y alimenta tanto 's'
// como 'cout'. Ahorra una compuerta por bit.
//
// Compuertas: 2 XOR + 2 AND + 1 OR = 5
//=====================================================================

module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire s,
    output wire cout
);
    wire ab;        // a XOR b
    wire c_ab;      // a AND b
    wire c_abcin;   // (a XOR b) AND cin

    xor x0 (ab,      a,     b);
    xor x1 (s,       ab,    cin);
    and a0 (c_ab,    a,     b);
    and a1 (c_abcin, ab,    cin);
    or  o0 (cout,    c_ab,  c_abcin);
endmodule
