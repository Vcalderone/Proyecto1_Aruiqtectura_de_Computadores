//=====================================================================
// control_tb.v -- Testbench de counter4, reg4 y fsm_control
//
// Verifica:
//   1. counter4  sube 0..15 y da la vuelta a 0 (modulo 16)
//   2. counter4  baja 0..1 pasando por 15 (modulo 16)
//   3. counter4  con en=0 no cuenta, aunque lleguen pulsos
//   4. counter4  con inc y dec juntos gana inc
//   5. reg4      carga con load=1, retiene con load=0
//   6. fsm       secuencia S0->S1->S2->S3->S0 con confirmar
//   7. fsm       usar_anterior avanza SOLO en S2
//   8. fsm       sel_op2 y load_R salen en el ciclo correcto
//   9. fsm       en_op/en_A/en_B/en_R son one-hot siempre
//
// SIN if NI case.
//=====================================================================

`timescale 1ns/1ps

module control_tb;

    reg  clk, rst;

    // counter4
    reg        c_en, c_inc, c_dec;
    wire [3:0] c_val;

    // reg4
    reg        r_load;
    reg  [3:0] r_in;
    wire [3:0] r_q;

    // fsm
    reg        f_conf, f_usar;
    wire       s1, s0, en_op, en_A, en_B, en_R, sel_op2, load_R;

    integer errores, casos;
    integer i, fallas_oh;

    reg        hubo;
    reg [79:0] veredicto [0:1];

    counter4    cnt (clk, rst, c_en, c_inc, c_dec, c_val);
    reg4        rg  (clk, rst, r_load, r_in, r_q);
    fsm_control fsm (clk, rst, f_conf, f_usar,
                     s1, s0, en_op, en_A, en_B, en_R, sel_op2, load_R);

    initial begin
        clk = 0;
        forever #1 clk = ~clk;
    end

    //-----------------------------------------------------------------
    // Las cuatro habilitaciones deben ser one-hot en todo momento
    //-----------------------------------------------------------------
    wire [2:0] activas = en_op + en_A + en_B + en_R;

    // Se muestrea en FLANCO DE BAJADA, no de subida. En el flanco de
    // subida las asignaciones no bloqueantes (q <= d) todavia no se
    // resolvieron, y ni #0 alcanza: #0 corre en la region inactiva, que
    // va ANTES de la region NBA. En el primer flanco se verian los
    // registros aun en X y saldria una falla falsa. A mitad de ciclo
    // todo esta asentado.
    always @(negedge clk)
        fallas_oh = fallas_oh + (activas !== 3'd1);

    task cuenta;
        input mal;
        begin
            casos   = casos + 1;
            errores = errores + mal;
            hubo    = hubo | mal;
        end
    endtask

    // Un pulso de un ciclo en confirmar
    task conf;
        begin
            @(negedge clk); f_conf = 1;
            @(negedge clk); f_conf = 0;
        end
    endtask

    // Un pulso de un ciclo en usar_anterior
    task usar;
        begin
            @(negedge clk); f_usar = 1;
            @(negedge clk); f_usar = 0;
        end
    endtask

    // Un pulso de un ciclo en inc
    task subir;
        begin
            @(negedge clk); c_inc = 1;
            @(negedge clk); c_inc = 0;
        end
    endtask

    task bajar;
        begin
            @(negedge clk); c_dec = 1;
            @(negedge clk); c_dec = 0;
        end
    endtask

    //-----------------------------------------------------------------
    initial begin
        $dumpfile("control.vcd");
        $dumpvars(0, control_tb);
        $timeformat(-9, 0, " ns", 8);

        veredicto[0] = "TODO OK   ";
        veredicto[1] = "HAY FALLAS";

        errores = 0; casos = 0; hubo = 0; fallas_oh = 0;
        rst = 1;
        c_en = 0; c_inc = 0; c_dec = 0;
        r_load = 0; r_in = 0;
        f_conf = 0; f_usar = 0;

        @(negedge clk); @(negedge clk);
        rst = 0;

        $display("=====================================================");
        $display(" counter4 + reg4 + fsm_control");
        $display("=====================================================");

        //-------------------------------------------------------------
        // 1. counter4 subiendo: 0..15 y vuelta a 0
        //-------------------------------------------------------------
        $display("--- 1. counter4 subiendo (modulo 16) --------------");
        c_en = 1;
        cuenta(c_val !== 4'd0);
        for (i = 1; i <= 16; i = i + 1) begin
            subir;
            cuenta(c_val !== i[3:0]);
        end
        $display("  tras 16 pulsos: val = %b  (esperado 0000, dio la vuelta)",
                 c_val);
        $display("");

        //-------------------------------------------------------------
        // 2. counter4 bajando: 0 -> 15 -> 14 ...
        //-------------------------------------------------------------
        $display("--- 2. counter4 bajando (modulo 16) ---------------");
        for (i = 1; i <= 16; i = i + 1) begin
            bajar;
            cuenta(c_val !== (16 - i));
        end
        $display("  tras 16 pulsos: val = %b  (esperado 0000)", c_val);
        $display("");

        //-------------------------------------------------------------
        // 3. en = 0 : no cuenta aunque lleguen pulsos
        //-------------------------------------------------------------
        $display("--- 3. counter4 deshabilitado ---------------------");
        subir; subir; subir;           // deja el contador en 3
        c_en = 0;
        for (i = 0; i < 5; i = i + 1) begin
            subir;
            cuenta(c_val !== 4'd3);
        end
        for (i = 0; i < 5; i = i + 1) begin
            bajar;
            cuenta(c_val !== 4'd3);
        end
        $display("  tras 10 pulsos con en=0: val = %b  (esperado 0011)", c_val);
        c_en = 1;
        $display("");

        //-------------------------------------------------------------
        // 4. inc y dec simultaneos: gana inc
        //-------------------------------------------------------------
        $display("--- 4. inc y dec juntos (gana inc) ----------------");
        @(negedge clk); c_inc = 1; c_dec = 1;
        @(negedge clk); c_inc = 0; c_dec = 0;
        cuenta(c_val !== 4'd4);
        $display("  desde 3 con inc+dec: val = %b  (esperado 0100)", c_val);
        $display("");

        //-------------------------------------------------------------
        // 5. reg4 : carga y retencion
        //-------------------------------------------------------------
        $display("--- 5. reg4 ---------------------------------------");
        @(negedge clk); r_in = 4'b1011; r_load = 1;
        @(negedge clk); r_load = 0;
        cuenta(r_q !== 4'b1011);
        $display("  tras cargar 1011: q = %b", r_q);

        @(negedge clk); r_in = 4'b0110;      // cambia la entrada, sin load
        for (i = 0; i < 4; i = i + 1) @(negedge clk);
        cuenta(r_q !== 4'b1011);
        $display("  con load=0 y entrada 0110: q = %b  (retiene)", r_q);

        @(negedge clk); r_load = 1;
        @(negedge clk); r_load = 0;
        cuenta(r_q !== 4'b0110);
        $display("  tras cargar 0110: q = %b", r_q);
        $display("");

        //-------------------------------------------------------------
        // 6. FSM: vuelta completa con confirmar
        //-------------------------------------------------------------
        $display("--- 6. FSM: S0 -> S1 -> S2 -> S3 -> S0 ------------");
        cuenta({s1, s0} !== 2'b00);
        cuenta(en_op !== 1'b1);
        $display("  estado inicial : %b%b   en_op=%b", s1, s0, en_op);

        conf;
        cuenta({s1, s0} !== 2'b01);
        cuenta(en_A !== 1'b1);
        $display("  tras confirmar : %b%b   en_A =%b", s1, s0, en_A);

        conf;
        cuenta({s1, s0} !== 2'b10);
        cuenta(en_B !== 1'b1);
        $display("  tras confirmar : %b%b   en_B =%b", s1, s0, en_B);

        conf;
        cuenta({s1, s0} !== 2'b11);
        cuenta(en_R !== 1'b1);
        $display("  tras confirmar : %b%b   en_R =%b", s1, s0, en_R);

        conf;
        cuenta({s1, s0} !== 2'b00);
        $display("  tras confirmar : %b%b   vuelta a S0", s1, s0);
        $display("");

        //-------------------------------------------------------------
        // 7. Sin pulso el estado se retiene
        //-------------------------------------------------------------
        $display("--- 7. retencion sin pulso ------------------------");
        for (i = 0; i < 10; i = i + 1) begin
            @(negedge clk);
            cuenta({s1, s0} !== 2'b00);
        end
        $display("  10 ciclos sin pulso: estado = %b%b", s1, s0);
        $display("");

        //-------------------------------------------------------------
        // 8. usar_anterior NO debe avanzar fuera de S2
        //-------------------------------------------------------------
        $display("--- 8. usar_anterior fuera de S2 (no avanza) ------");
        usar;                                  // en S0
        cuenta({s1, s0} !== 2'b00);
        cuenta(sel_op2 !== 1'b0);
        cuenta(load_R  !== 1'b0);
        $display("  usar en S0: estado = %b%b  sel_op2=%b  load_R=%b",
                 s1, s0, sel_op2, load_R);

        conf;                                  // -> S1
        usar;
        cuenta({s1, s0} !== 2'b01);
        $display("  usar en S1: estado = %b%b  (no avanza)", s1, s0);
        $display("");

        //-------------------------------------------------------------
        // 9. usar_anterior en S2: avanza, y saca sel_op2 y load_R
        //    en el MISMO ciclo (por eso sel_op2 es combinacional)
        //-------------------------------------------------------------
        $display("--- 9. usar_anterior en S2 ------------------------");
        conf;                                  // -> S2
        cuenta({s1, s0} !== 2'b10);

        @(negedge clk); f_usar = 1;
        #0;
        cuenta(sel_op2 !== 1'b1);
        cuenta(load_R  !== 1'b1);
        $display("  durante el pulso: sel_op2=%b  load_R=%b  (los dos en 1)",
                 sel_op2, load_R);
        @(negedge clk); f_usar = 0;
        #0;

        cuenta({s1, s0} !== 2'b11);
        cuenta(sel_op2 !== 1'b0);
        $display("  tras el pulso   : estado = %b%b  sel_op2=%b  (ya cayo)",
                 s1, s0, sel_op2);
        $display("");

        //-------------------------------------------------------------
        // 10. load_R sale tambien con confirmar en S2, y solo ahi
        //-------------------------------------------------------------
        $display("--- 10. load_R solo en S2 -------------------------");
        conf;                                  // S3 -> S0
        cuenta({s1, s0} !== 2'b00);

        @(negedge clk); f_conf = 1; #0;
        cuenta(load_R !== 1'b0);               // en S0 no carga
        $display("  confirmar en S0: load_R=%b", load_R);
        @(negedge clk); f_conf = 0;            // -> S1

        @(negedge clk); f_conf = 1; #0;
        cuenta(load_R !== 1'b0);               // en S1 tampoco
        $display("  confirmar en S1: load_R=%b", load_R);
        @(negedge clk); f_conf = 0;            // -> S2

        @(negedge clk); f_conf = 1; #0;
        cuenta(load_R !== 1'b1);               // en S2 SI
        $display("  confirmar en S2: load_R=%b", load_R);
        @(negedge clk); f_conf = 0;
        $display("");

        //-------------------------------------------------------------
        $display("Casos verificados : %0d", casos);
        $display("Errores           : %0d", errores);
        $display("Fallas one-hot    : %0d", fallas_oh);
        $display("");
        $display(">>> control: %s", veredicto[hubo | (fallas_oh !== 0)]);

        $finish;
    end

endmodule
