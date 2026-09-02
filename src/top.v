//=====================================================================
// top.v -- Calculadora de 4 bits en complemento a dos
//          Nandland Go Board -- Lattice iCE40 HX1K VQ100
//
// Los nombres de los puertos son los del Go_Board_Constraints.pcf
// oficial de Nandland, no se pueden cambiar.
//
// FLUJO DE USO
//   S0  se elige la operacion con los botones izquierdos.
//       Codigo en los LEDs, guion en los dos displays.
//   S1  se ingresa A. Se muestra como signo + magnitud.
//   S2  se ingresa B. Se muestra como signo + magnitud.
//       El boton inferior derecho usa el resultado anterior como B
//       y ejecuta de inmediato.
//   S3  se muestra el resultado. El superior derecho vuelve a S0.
//
// A y B NO se reinician entre rondas: mantienen su valor y se
// sobreescriben. Como los contadores son modulo 16 con subir y bajar,
// desde cualquier valor se llega a cualquier otro en 8 pulsaciones.
// La operacion 3'b000 reinicia el RESULTADO, que es lo que pide el
// enunciado.
//
//   Requiere: full_adder adder4 mux2 shift_left shift_right op_decoder
//             alu op_selector counter4 reg4 fsm_control prescaler
//             debounce display_src abs4 seg7_decoder display_chain
//             dash_s0 por
//=====================================================================

module top (
    input  wire i_Clk,           // 25 MHz, oscilador de la placa

    input  wire i_Switch_1,      // superior izquierdo -- incrementar
    input  wire i_Switch_2,      // inferior izquierdo -- decrementar
    input  wire i_Switch_3,      // superior derecho   -- confirmar
    input  wire i_Switch_4,      // inferior derecho   -- usar anterior

    output wire o_LED_1,         // op[2]
    output wire o_LED_2,         // op[1]
    output wire o_LED_3,         // op[0]
    output wire o_LED_4,         // encendido en S3 (mostrando resultado)

    output wire o_Segment1_A,    // display izquierdo -- signo
    output wire o_Segment1_B,
    output wire o_Segment1_C,
    output wire o_Segment1_D,
    output wire o_Segment1_E,
    output wire o_Segment1_F,
    output wire o_Segment1_G,

    output wire o_Segment2_A,    // display derecho -- magnitud
    output wire o_Segment2_B,
    output wire o_Segment2_C,
    output wire o_Segment2_D,
    output wire o_Segment2_E,
    output wire o_Segment2_F,
    output wire o_Segment2_G
);

    //=================================================================
    // BLOQUE DE POLARIDAD DE ENTRADA
    //
    // Todo el diseno esta en logica positiva: boton apretado = 1.
    // Si la Go Board resulta activa en BAJO, cambiar los cuatro 'buf'
    // de abajo por 'not'. No hay que tocar nada mas.
    //
    // Prueba: cargar el diseno y ver si el codigo de operacion avanza
    // al apretar, o si avanza solo sin apretar nada.
    //=================================================================
    wire sw_inc, sw_dec, sw_conf, sw_usar;

    buf pb1 (sw_inc,  i_Switch_1);
    buf pb2 (sw_dec,  i_Switch_2);
    buf pb3 (sw_conf, i_Switch_3);
    buf pb4 (sw_usar, i_Switch_4);

    //=================================================================
    // Reset de encendido y tick de muestreo
    //=================================================================
    wire rst, tick;

    por       poweron (i_Clk, rst);
    prescaler pre     (i_Clk, rst, tick);

    //=================================================================
    // Botones: filtro de rebote + pulso de un ciclo
    //=================================================================
    wire niv_inc,  p_inc;
    wire niv_dec,  p_dec;
    wire niv_conf, p_conf;
    wire niv_usar, p_usar;

    boton b1 (i_Clk, rst, tick, sw_inc,  niv_inc,  p_inc );
    boton b2 (i_Clk, rst, tick, sw_dec,  niv_dec,  p_dec );
    boton b3 (i_Clk, rst, tick, sw_conf, niv_conf, p_conf);
    boton b4 (i_Clk, rst, tick, sw_usar, niv_usar, p_usar);

    //=================================================================
    // Maquina de estados
    //=================================================================
    wire s1, s0;
    wire en_op, en_A, en_B, en_R;
    wire sel_op2, load_R;

    fsm_control fsm (
        i_Clk, rst, p_conf, p_usar,
        s1, s0, en_op, en_A, en_B, en_R, sel_op2, load_R
    );

    //=================================================================
    // Selector de operacion (solo responde en S0)
    //
    // op_selector no tiene entrada de habilitacion, asi que se filtran
    // sus pulsos con en_op. Sin esto, subir en S1 cambiaria tambien el
    // codigo de operacion.
    //=================================================================
    wire inc_op, dec_op;
    wire [2:0] op;

    and go1 (inc_op, p_inc, en_op);
    and go2 (dec_op, p_dec, en_op);

    op_selector opsel (i_Clk, rst, inc_op, dec_op, op);

    //=================================================================
    // Contadores de operandos
    //
    // Los dos reciben los mismos pulsos; el 'en' de cada uno decide
    // cual responde. en_A y en_B vienen de la FSM y son one-hot.
    //=================================================================
    wire [3:0] A, op2;

    counter4 cA (i_Clk, rst, en_A, p_inc, p_dec, A  );
    counter4 cB (i_Clk, rst, en_B, p_inc, p_dec, op2);

    //=================================================================
    // Selector del segundo operando
    //   sel_op2 = 0  ->  B = op2   (el contador)
    //   sel_op2 = 1  ->  B = R     (resultado anterior)
    //
    // sel_op2 es combinacional: vale 1 en el mismo ciclo en que se
    // carga el registro, que es justo el que importa.
    //=================================================================
    wire [3:0] B, R, R_next;

    mux2 mb0 (op2[0], R[0], sel_op2, B[0]);
    mux2 mb1 (op2[1], R[1], sel_op2, B[1]);
    mux2 mb2 (op2[2], R[2], sel_op2, B[2]);
    mux2 mb3 (op2[3], R[3], sel_op2, B[3]);

    //=================================================================
    // ALU y registro de resultado
    //
    // La realimentacion R -> B -> R_next -> registro -> R no es lazo
    // combinacional: el flip-flop corta el camino.
    //=================================================================
    alu  core (A, B, op, R_next);
    reg4 rr   (i_Clk, rst, load_R, R_next, R);

    //=================================================================
    // Cadena de visualizacion
    //
    // La fuente la elige el estado: A en S1, op2 en S2, R en S3.
    // En S0 se muestra un guion, asi que la entrada v_s0 no importa y
    // se ata a cero.
    //
    // Se muestra op2 y no B: apretar el boton inferior derecho avanza
    // a S3 de inmediato, asi que B = R nunca alcanza a verse en S2.
    //=================================================================
    wire [3:0] V, D;
    wire       signo;
    wire [6:0] izq_raw, der_raw;
    wire [6:0] izq, der;

    display_chain disp (
        4'b0000,          // v_s0: irrelevante, en S0 va el guion
        A, op2, R,
        s1, s0,
        V, signo, D,
        izq_raw, der_raw
    );

    dash_s0 guion (en_op, izq_raw, der_raw, izq, der);

    //=================================================================
    // LEDs: codigo de operacion, LED_1 es el bit mas significativo
    //=================================================================
    buf l1 (o_LED_1, op[2]);
    buf l2 (o_LED_2, op[1]);
    buf l3 (o_LED_3, op[0]);
    buf l4 (o_LED_4, en_R);

    //=================================================================
    // BLOQUE DE POLARIDAD DE SALIDA
    //
    // VERIFICADO EN LA PLACA: el display 5261BG es ANODO COMUN, o sea
    // ACTIVO EN BAJO. Por eso aca van 'not' y no 'buf'.
    //
    // Como se detecto: con 'buf' los displays mostraban un 0 en vez del
    // guion de S0. El guion es solo el segmento g encendido (0000001);
    // invertido se prende todo menos g, que es exactamente un 0. El
    // patron complementario confirmo la polaridad.
    //
    // Esto es De Morgan aplicado en la salida y NO obliga a rehacer
    // ningun mapa de Karnaugh (decision 11 del handoff): toda la logica
    // interna sigue en logica positiva, solo cambia la compuerta final.
    //
    // Los LEDs son circuito aparte y SI son activos en alto, por eso
    // arriba quedan 'buf'.
    //
    // Formato del bus: seg[6:0] = {a,b,c,d,e,f,g}
    //=================================================================
    not s1a (o_Segment1_A, izq[6]);
    not s1b (o_Segment1_B, izq[5]);
    not s1c (o_Segment1_C, izq[4]);
    not s1d (o_Segment1_D, izq[3]);
    not s1e (o_Segment1_E, izq[2]);
    not s1f (o_Segment1_F, izq[1]);
    not s1g (o_Segment1_G, izq[0]);

    not s2a (o_Segment2_A, der[6]);
    not s2b (o_Segment2_B, der[5]);
    not s2c (o_Segment2_C, der[4]);
    not s2d (o_Segment2_D, der[3]);
    not s2e (o_Segment2_E, der[2]);
    not s2f (o_Segment2_F, der[1]);
    not s2g (o_Segment2_G, der[0]);

endmodule
