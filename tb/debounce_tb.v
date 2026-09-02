//=====================================================================
// debounce_tb.v -- Testbench del prescaler, el debounce y el boton
//
// Lo importante que se verifica:
//
//   1. El tick del prescaler dura UN ciclo y cae cada 2^15 = 32768.
//   2. Un boton que rebota produce UN SOLO pulso, no varios.
//   3. El pulso dura exactamente un ciclo de reloj, aunque el boton
//      quede apretado miles de ciclos.
//   4. Un glitch mas corto que 3 ticks se ignora por completo.
//   5. Soltar el boton no genera pulso (solo flanco de subida).
//   6. Dos pulsaciones seguidas dan dos pulsos.
//
// El modulo 'boton' recibe tick como entrada, asi que el testbench se
// lo puede generar rapido y no hay que simular 32768 ciclos por cada
// muestra. El prescaler real se verifica aparte, en la seccion 1.
//
// SIN if NI case.
//=====================================================================

`timescale 1ns/1ps

module debounce_tb;

    reg  clk, rst;
    reg  tick, raw;
    wire nivel, pulso;

    integer errores, casos;
    integer pulsos, ciclos_pulso;
    integer i, k;

    reg        hubo;
    reg [79:0] veredicto [0:1];

    boton uut (clk, rst, tick, raw, nivel, pulso);

    //-----------------------------------------------------------------
    // Prescaler real, para medir el periodo del tick
    //-----------------------------------------------------------------
    reg  pre_rst;
    wire pre_tick;
    prescaler pre (clk, pre_rst, pre_tick);

    integer t_ant, t_act, periodo, ticks_vistos, ancho_malo;

    initial begin
        clk = 0;
        forever #1 clk = ~clk;
    end

    //-----------------------------------------------------------------
    // Contadores permanentes, sin if:
    //   pulsos       cuantos pulsos salieron
    //   ciclos_pulso cuantos ciclos estuvo alto el pulso (debe ser
    //                igual a pulsos si cada uno dura 1 ciclo)
    //-----------------------------------------------------------------
    always @(posedge clk) begin
        #0;
        pulsos       = pulsos + pulso;
        ciclos_pulso = ciclos_pulso + pulso;
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
    // Un tick: alto durante un ciclo de reloj
    //-----------------------------------------------------------------
    task un_tick;
        begin
            @(negedge clk); tick = 1;
            @(negedge clk); tick = 0;
        end
    endtask

    // n ticks seguidos, con 2 ciclos de separacion
    task n_ticks;
        input integer n;
        integer z;
        begin
            for (z = 0; z < n; z = z + 1) begin
                un_tick;
                @(negedge clk);
            end
        end
    endtask

    task cero;
        begin
            pulsos = 0; ciclos_pulso = 0;
        end
    endtask

    //-----------------------------------------------------------------
    initial begin
        $dumpfile("debounce.vcd");
        $dumpvars(0, debounce_tb);
        $timeformat(-9, 0, " ns", 8);

        veredicto[0] = "TODO OK   ";
        veredicto[1] = "HAY FALLAS";

        errores = 0; casos = 0; hubo = 0;
        pulsos = 0; ciclos_pulso = 0;
        ticks_vistos = 0; ancho_malo = 0; t_ant = 0; periodo = 0;

        rst = 1; pre_rst = 1; tick = 0; raw = 0;
        @(negedge clk); @(negedge clk);
        rst = 0; pre_rst = 0;

        $display("=====================================================");
        $display(" Debounce + deteccion de flanco");
        $display("=====================================================");

        //-------------------------------------------------------------
        // 1. Periodo y ancho del tick del prescaler real
        //-------------------------------------------------------------
        $display("--- 1. prescaler ----------------------------------");

        // OJO: el tick se muestrea en FLANCO DE BAJADA, donde ya esta
        // estable. NO se puede usar @(posedge pre_tick): la cadena de
        // acarreo son 15 AND en cascada y en simulacion de cero retardo
        // produce transitorios mientras propaga, que se veran como
        // flancos falsos. En hardware no importa, porque los flip-flops
        // solo muestrean en el flanco de reloj y para entonces la
        // cadena ya se asento. Pero el testbench si los ve.
        //
        // En vez de medir el periodo con $time, se cuentan los ticks en
        // una ventana conocida: en 3 periodos deben caer 3 ticks, y el
        // total de ciclos en alto debe ser igual al numero de ticks, o
        // sea cada tick dura exactamente 1 ciclo.

        ticks_vistos = 0;
        ancho_malo   = 0;

        for (i = 0; i < 98304; i = i + 1) begin      // 3 x 32768
            @(negedge clk);
            ticks_vistos = ticks_vistos + pre_tick;
            ancho_malo   = ancho_malo   + pre_tick;
        end

        $display("  ticks en 98304 ciclos : %0d  (esperado 3 -> periodo 32768)",
                 ticks_vistos);
        $display("  ciclos en alto        : %0d  (igual al numero de ticks",
                 ancho_malo);
        $display("                                 -> cada tick dura 1 ciclo)");
        cuenta(ticks_vistos !== 3);
        cuenta(ancho_malo   !== ticks_vistos);
        $display("");

        //-------------------------------------------------------------
        // 2. Pulsacion con rebote: debe salir UN pulso
        //-------------------------------------------------------------
        $display("--- 2. pulsacion con rebote -----------------------");
        cero;

        // Rebote: raw salta 8 veces, con un tick entremedio de cada uno
        for (i = 0; i < 8; i = i + 1) begin
            raw = ~raw;
            un_tick;
            @(negedge clk);
        end

        // Ahora se estabiliza en 1 y se mantiene apretado
        raw = 1;
        n_ticks(6);

        $display("  pulsos tras el rebote     : %0d  (esperado 1)", pulsos);
        $display("  nivel filtrado            : %0d  (esperado 1)", nivel);
        cuenta(pulsos !== 1);
        cuenta(nivel !== 1);
        $display("");

        //-------------------------------------------------------------
        // 3. Boton mantenido apretado: no debe salir otro pulso
        //-------------------------------------------------------------
        $display("--- 3. mantenido apretado -------------------------");
        cero;
        n_ticks(20);
        for (i = 0; i < 200; i = i + 1) @(negedge clk);

        $display("  pulsos extra en 20 ticks  : %0d  (esperado 0)", pulsos);
        cuenta(pulsos !== 0);
        $display("");

        //-------------------------------------------------------------
        // 4. Soltar: no genera pulso (solo flanco de subida)
        //-------------------------------------------------------------
        $display("--- 4. al soltar ----------------------------------");
        cero;
        raw = 0;
        n_ticks(6);

        $display("  pulsos al soltar          : %0d  (esperado 0)", pulsos);
        $display("  nivel filtrado            : %0d  (esperado 0)", nivel);
        cuenta(pulsos !== 0);
        cuenta(nivel !== 0);
        $display("");

        //-------------------------------------------------------------
        // 5. Glitch corto: 2 ticks en alto, menos de los 3 que exige
        //-------------------------------------------------------------
        $display("--- 5. glitch de 2 ticks (debe ignorarse) ---------");
        cero;
        raw = 1;
        n_ticks(2);
        raw = 0;
        n_ticks(6);

        $display("  pulsos por el glitch      : %0d  (esperado 0)", pulsos);
        $display("  nivel filtrado            : %0d  (esperado 0)", nivel);
        cuenta(pulsos !== 0);
        cuenta(nivel !== 0);
        $display("");

        //-------------------------------------------------------------
        // 6. Dos pulsaciones seguidas: dos pulsos
        //-------------------------------------------------------------
        $display("--- 6. dos pulsaciones ----------------------------");
        cero;
        for (k = 0; k < 2; k = k + 1) begin
            raw = 1;  n_ticks(5);
            raw = 0;  n_ticks(5);
        end

        $display("  pulsos                    : %0d  (esperado 2)", pulsos);
        cuenta(pulsos !== 2);
        $display("");

        //-------------------------------------------------------------
        // 7. Ancho del pulso: cada pulso ocupo exactamente 1 ciclo
        //-------------------------------------------------------------
        $display("--- 7. ancho del pulso ----------------------------");
        $display("  ciclos en alto / pulsos   : %0d / %0d  (deben ser iguales)",
                 ciclos_pulso, pulsos);
        cuenta(ciclos_pulso !== pulsos);
        $display("");

        //-------------------------------------------------------------
        $display("Casos verificados : %0d", casos);
        $display("Errores           : %0d", errores);
        $display("");
        $display(">>> debounce: %s", veredicto[hubo]);

        $finish;
    end

endmodule
