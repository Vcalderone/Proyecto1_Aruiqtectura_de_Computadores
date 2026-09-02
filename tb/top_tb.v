//=====================================================================
// top_tb.v -- Testbench punta a punta del modulo top
//
// Simula pulsaciones REALES: aprieta los botones fisicos, pasa por el
// filtro de rebote (3 ticks del prescaler = 98304 ciclos por muestra),
// recorre la FSM y lee los segmentos de salida. Es lento a proposito:
// es la unica forma de comprobar que la cadena completa funciona.
//
// Verifica:
//   1. Al arrancar: S0, guion en los dos displays, LEDs en 000
//   2. Elegir operacion sube el codigo y se ve en los LEDs
//   3. Ingresar A y B con los botones, con el display correcto
//   4. El resultado aparece en S3
//   5. Reutilizar el resultado como B con el boton inferior derecho
//   6. La operacion 000 pone el resultado en cero
//   7. A y B mantienen su valor entre rondas
//   8. Los botones izquierdos no hacen nada en S3
//
// SIN if NI case.
//=====================================================================

`timescale 1ns/1ps

module top_tb;

    reg  clk;
    reg  sw1, sw2, sw3, sw4;

    wire led1, led2, led3, led4;
    wire g1a, g1b, g1c, g1d, g1e, g1f, g1g;
    wire g2a, g2b, g2c, g2d, g2e, g2f, g2g;

    integer errores, casos;
    integer i;

    reg        hubo;
    reg [79:0] veredicto [0:1];
    reg [127:0] letra;

    top uut (
        clk, sw1, sw2, sw3, sw4,
        led1, led2, led3, led4,
        g1a, g1b, g1c, g1d, g1e, g1f, g1g,
        g2a, g2b, g2c, g2d, g2e, g2f, g2g
    );

    //-----------------------------------------------------------------
    // Los pines de segmento salen ACTIVOS EN BAJO: el display 5261BG es
    // de anodo comun, asi que top.v invierte los catorce con 'not'.
    // Aca se vuelven a invertir para poder escribir los patrones
    // esperados en logica positiva (1 = segmento encendido), que es como
    // estan las tablas del informe y el resto de los testbenches.
    //-----------------------------------------------------------------
    wire [6:0] izq = ~{g1a, g1b, g1c, g1d, g1e, g1f, g1g};
    wire [6:0] der = ~{g2a, g2b, g2c, g2d, g2e, g2f, g2g};
    wire [2:0] leds = {led1, led2, led3};

    initial begin
        clk = 0;
        forever #1 clk = ~clk;
    end

    task cuenta;
        input mal;
        begin
            casos   = casos + 1;
            errores = errores + mal;
            hubo    = hubo | mal;
        end
    endtask

    //-----------------------------------------------------------------
    // Espera n ticks del prescaler, muestreando en flanco de bajada
    // (en flanco de subida la cadena de acarreo todavia glitchea).
    //-----------------------------------------------------------------
    task espera_ticks;
        input integer n;
        integer vistos;
        begin
            vistos = 0;
            while (vistos < n) begin
                @(negedge clk);
                vistos = vistos + uut.tick;
            end
        end
    endtask

    //-----------------------------------------------------------------
    // Una pulsacion completa: apretar, mantener 4 ticks, soltar,
    // esperar 4 ticks. El debounce necesita 3 para aceptar.
    //-----------------------------------------------------------------
    task aprieta_1; begin sw1 = 1; espera_ticks(4); sw1 = 0; espera_ticks(4); end endtask
    task aprieta_2; begin sw2 = 1; espera_ticks(4); sw2 = 0; espera_ticks(4); end endtask
    task aprieta_3; begin sw3 = 1; espera_ticks(4); sw3 = 0; espera_ticks(4); end endtask
    task aprieta_4; begin sw4 = 1; espera_ticks(4); sw4 = 0; espera_ticks(4); end endtask

    // Sube n veces el valor actual
    task sube;
        input integer n;
        integer z;
        begin
            for (z = 0; z < n; z = z + 1) aprieta_1;
        end
    endtask

    task baja;
        input integer n;
        integer z;
        begin
            for (z = 0; z < n; z = z + 1) aprieta_2;
        end
    endtask

    // Dibuja los segmentos encendidos, sin operador ternario
    function [7:0] pinta;
        input       on;
        input [7:0] c;
        begin
            pinta = ({8{on}} & c) | ({8{~on}} & ".");
        end
    endfunction

    function [55:0] dibujo;
        input [6:0] s;
        begin
            dibujo = { pinta(s[6], "a"), pinta(s[5], "b"), pinta(s[4], "c"),
                       pinta(s[3], "d"), pinta(s[2], "e"), pinta(s[1], "f"),
                       pinta(s[0], "g") };
        end
    endfunction

    function integer con_signo;
        input [3:0] v;
        begin
            con_signo = v - (16 * v[3]);
        end
    endfunction

    task muestra;
        input [127:0] etiqueta;   // 16 caracteres
        begin
            $display("  %-0s  estado=%b%b  LEDs=%b  izq[%0s] der[%0s]   A=%0d B=%0d R=%0d",
                     etiqueta, uut.s1, uut.s0, leds,
                     dibujo(izq), dibujo(der),
                     con_signo(uut.A), con_signo(uut.op2), con_signo(uut.R));
        end
    endtask

    //-----------------------------------------------------------------
    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, top_tb);
        $timeformat(-9, 0, " ns", 8);

        veredicto[0] = "TODO OK   ";
        veredicto[1] = "HAY FALLAS";

        errores = 0; casos = 0; hubo = 0;
        sw1 = 0; sw2 = 0; sw3 = 0; sw4 = 0;

        $display("=====================================================");
        $display(" top -- calculadora completa, pulsaciones reales");
        $display("=====================================================");

        //-------------------------------------------------------------
        // 1. Arranque: S0, guion en los dos, LEDs apagados
        //-------------------------------------------------------------
        espera_ticks(2);
        $display("--- 1. Arranque -----------------------------------");
        muestra("inicio      :");
        cuenta({uut.s1, uut.s0} !== 2'b00);
        cuenta(izq  !== 7'b0000001);      // solo g
        cuenta(der  !== 7'b0000001);      // solo g
        cuenta(leds !== 3'b000);
        $display("");

        //-------------------------------------------------------------
        // 2. Elegir SUMA (001): una subida
        //-------------------------------------------------------------
        $display("--- 2. Elegir SUMA (001) --------------------------");
        sube(1);
        muestra("op=001      :");
        cuenta(leds !== 3'b001);
        cuenta(der  !== 7'b0000001);      // sigue el guion en S0
        $display("");

        //-------------------------------------------------------------
        // 3. Confirmar -> S1, ingresar A = 3
        //-------------------------------------------------------------
        $display("--- 3. Ingresar A = 3 -----------------------------");
        aprieta_3;
        cuenta({uut.s1, uut.s0} !== 2'b01);
        sube(3);
        muestra("A=3         :");
        cuenta(uut.A !== 4'd3);
        cuenta(der   !== 7'b1111001);     // el 3
        cuenta(izq   !== 7'b0000000);     // signo positivo: todo apagado
        $display("");

        //-------------------------------------------------------------
        // 4. Confirmar -> S2, ingresar B = 2
        //-------------------------------------------------------------
        $display("--- 4. Ingresar B = 2 -----------------------------");
        aprieta_3;
        cuenta({uut.s1, uut.s0} !== 2'b10);
        sube(2);
        muestra("B=2         :");
        cuenta(uut.op2 !== 4'd2);
        cuenta(der     !== 7'b1101101);   // el 2
        $display("");

        //-------------------------------------------------------------
        // 5. Confirmar -> S3: R = 3 + 2 = 5
        //-------------------------------------------------------------
        $display("--- 5. Resultado 3 + 2 ----------------------------");
        aprieta_3;
        muestra("R=5         :");
        cuenta({uut.s1, uut.s0} !== 2'b11);
        cuenta(uut.R !== 4'd5);
        cuenta(der   !== 7'b1011011);     // el 5
        cuenta(izq   !== 7'b0000000);     // positivo
        cuenta(led4  !== 1'b1);           // LED_4 encendido en S3
        $display("");

        //-------------------------------------------------------------
        // 6. Los botones izquierdos no hacen nada en S3
        //-------------------------------------------------------------
        $display("--- 6. Izquierdos inertes en S3 -------------------");
        sube(2); baja(1);
        muestra("sin cambio  :");
        cuenta(uut.R !== 4'd5);
        cuenta({uut.s1, uut.s0} !== 2'b11);
        $display("");

        //-------------------------------------------------------------
        // 7. Volver a S0. A y B deben CONSERVAR su valor.
        //-------------------------------------------------------------
        $display("--- 7. Vuelta a S0, A y B se conservan ------------");
        aprieta_3;
        muestra("de vuelta   :");
        cuenta({uut.s1, uut.s0} !== 2'b00);
        cuenta(uut.A   !== 4'd3);
        cuenta(uut.op2 !== 4'd2);
        $display("");

        //-------------------------------------------------------------
        // 8. Elegir RESTA (010) y reutilizar el resultado como B
        //    3 - 5 = -2, usando el boton inferior derecho
        //-------------------------------------------------------------
        $display("--- 8. RESTA reutilizando el resultado ------------");
        sube(1);                          // 001 -> 010
        cuenta(leds !== 3'b010);
        aprieta_3;                        // -> S1, A sigue en 3
        cuenta(uut.A !== 4'd3);
        aprieta_3;                        // -> S2
        cuenta({uut.s1, uut.s0} !== 2'b10);

        aprieta_4;                        // usar anterior: B = R = 5
        muestra("R=3-5=-2    :");
        cuenta({uut.s1, uut.s0} !== 2'b11);
        cuenta(uut.R !== 4'b1110);        // -2
        cuenta(izq   !== 7'b0000001);     // signo negativo: guion
        cuenta(der   !== 7'b1101101);     // magnitud 2
        $display("");

        //-------------------------------------------------------------
        // 9. Operacion REINICIO: pone el resultado en cero
        //-------------------------------------------------------------
        $display("--- 9. REINICIO (000) -----------------------------");
        aprieta_3;                        // -> S0
        baja(2);                          // 010 -> 001 -> 000
        cuenta(leds !== 3'b000);
        aprieta_3;                        // -> S1
        aprieta_3;                        // -> S2
        aprieta_3;                        // -> S3, ejecuta reinicio
        muestra("R=0         :");
        cuenta(uut.R !== 4'd0);
        cuenta(der   !== 7'b1111110);     // el 0
        $display("");

        //-------------------------------------------------------------
        $display("Casos verificados : %0d", casos);
        $display("Errores           : %0d", errores);
        $display("");
        $display(">>> top: %s", veredicto[hubo]);

        $finish;
    end

endmodule
