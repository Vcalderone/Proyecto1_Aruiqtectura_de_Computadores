# Proyecto 1 — Calculadora de 4 bits en complemento a dos

Arquitectura de Computadores · Universidad de los Andes · Semestre 2026-2
Nandland Go Board — FPGA Lattice iCE40 HX1K (VQ100)

Calculadora de 4 bits con números negativos en complemento a dos (rango −8 a +7),
con seis operaciones, entrada por los cuatro botones de la placa y salida por los
LEDs y los dos displays de siete segmentos.

El informe con el diseño, las tablas de verdad, los mapas de Karnaugh y las
expresiones booleanas está en `Informe_Proyecto1_Calculadora4bits.pdf`.

## Restricción de diseño

Toda la lógica combinacional está descrita **exclusivamente con primitivas de
compuerta** de Verilog: `and`, `or`, `not`, `xor`, `nand`, `nor`, `xnor`, `buf`.

No se usa `+`, `-`, `<`, `>`, `<=`, `>=`, `<<`, `>>`, `?:`, `if` ni `case` en
ningún archivo de `src/`. Lo único secuencial son los bloques
`always @(posedge clk) q <= d;`, cuya entrada `d` se calcula íntegramente con
compuertas — incluido el reset síncrono, que es un `and` con `rst` por bit.

## Operaciones

| Código | Operación | Resultado |
|---|---|---|
| `000` | Reinicio | `R = 0000` |
| `001` | Suma | `R = A + B` |
| `010` | Resta | `R = A − B` |
| `011` | Resta inversa | `R = B − A` |
| `100` | Shift left | `R = A << B[1:0]` |
| `101` | Shift right | `R = A >> B[1:0]` |
| `110`, `111` | Inválidos | `R = 0000` (no alcanzables desde los botones) |

Aritmética módulo 16: si una operación desborda se conservan los cuatro bits menos
significativos. Los desplazamientos son lógicos (rellenan con ceros) y solo
`B[1:0]` controla la cantidad.

## Estructura del repositorio

```
src/    19 archivos, 25 módulos — el diseño
tb/     11 testbenches propios + 4 sesiones de GTKWave (.gtkw)
sim.bat script de simulación y síntesis (Windows)
Makefile equivalente para GNU Make
go_board.pcf asignación de pines (del archivo oficial de Nandland)
```

Hay **dos niveles superiores**, que comparten el mismo núcleo:

| Módulo | Para qué |
|---|---|
| `top` | La calculadora en la placa: botones, debounce, FSM de 4 estados, LEDs y displays. |
| `calculadora_4bits` | La misma ALU y el mismo registro, pero con la interfaz que pide el testbench de la evaluación: entradas directas y una señal `ejecutar`. |

`calculadora_4bits` no reimplementa nada: instancia la misma `alu` y los mismos
`mux2` que usa `top`. Solo saca el camino de datos de adentro de la máquina de
estados y lo expone en puertos.

## Cómo simular

Abrir la consola de OSS CAD Suite con `start.bat`, navegar hasta esta carpeta y:

```
sim.bat            todos los testbenches rápidos
sim.bat adder4     sumador de 4 bits
sim.bat shifter    barrel shifters
sim.bat opsel      selector de operación
sim.bat alu        ALU completa
sim.bat display    cadena de display
sim.bat debounce   debounce y prescaler
sim.bat control    contadores, registro y FSM
sim.bat calc       envoltorio calculadora_4bits
sim.bat top        calculadora completa (lento, 2-3 min)
sim.bat demo       casos de la evaluación presencial
sim.bat wave       onda curada de la ALU
sim.bat clean      borra los archivos de simulación
sim.bat distclean  borra también el bitstream
```

`sim.bat` termina con errorlevel 0 solo si **ningún** testbench reportó errores, y
al final imprime el veredicto global. Un testbench que falla lo dice con
`*** <nombre>: el testbench reporto errores ***`.

Para ver las ondas:

```
gtkwave demo.vcd tb/demo.gtkw
gtkwave alu_wave.vcd tb/alu_wave.gtkw
gtkwave calculadora_4bits.vcd tb/calculadora_4bits.gtkw
```

### Evaluación presencial

Los valores dictados en clase se escriben en `tb/demo_tb.v`, en el bloque marcado
entre los dos comentarios grandes, en decimal con signo (−8 a 7):

```verilog
caso( 3, 2, SUMA);      // caso(A, B, operacion)
caso(-4, 2, RESTA);
```

Operaciones disponibles: `REINICIO` `SUMA` `RESTA` `RESTA_I` `SHL` `SHR`.
Después `sim.bat demo` y `gtkwave demo.vcd tb/demo.gtkw`. La sesión de GTKWave ya
trae cargadas las entradas, las seis líneas one-hot del decodificador, las señales
de control (`sub`, `swap`), las vías internas (`sum`, `shl`, `shr`) y el resultado.

### Testbench de la cátedra

El día de la evaluación entregan un testbench que instancia `calculadora_4bits`
con esta interfaz:

```verilog
module calculadora_4bits (
  input  wire       clk,
  input  wire       ejecutar,     // confirma / ejecuta la operación
  input  wire [2:0] codigo,       // selector de operación
  input  wire       sel_op2,      // 0 = op2_ext, 1 = resultado anterior
  input  wire [3:0] op1,
  input  wire [3:0] op2_ext,
  output wire [3:0] resultado
);
```

Ese testbench **no tiene target en `sim.bat`**: no se sabe de antemano cómo se va
a llamar el archivo ni qué va a probar. Se corre a mano, pegando esto y cambiando
**solo el último argumento** por el archivo que entreguen:

```bash
iverilog -g2012 -o sim_prof src/abs4.v src/adder4.v src/alu.v src/calculadora_4bits.v src/counter4.v src/dash_s0.v src/debounce.v src/display_chain.v src/display_src.v src/fsm_control.v src/full_adder.v src/mux2.v src/op_decoder.v src/op_selector.v src/prescaler.v src/seg7_decoder.v src/shift_left.v src/shift_right.v src/top.v tb\EL_ARCHIVO.sv
```

```bash
vvp sim_prof
```

Dos detalles que importan:

- **`-g2012` no es opcional.** El testbench es SystemVerilog (`logic`, `string`,
  `task automatic`). Sin esa bandera Icarus tira errores de sintaxis en `logic` y
  parece que el diseño está roto, cuando el problema es la bandera.
- El comando compila **todo `src/`**, no solo lo que necesita el envoltorio. Es a
  propósito: si el testbench instancia cualquier otro módulo, ya está disponible y
  no hay que salir a buscar qué falta en medio de la evaluación.

Para mostrar la onda:

```bash
gtkwave calculadora_4bits_tb_basico.vcd tb/calculadora_4bits_basico.gtkw
```

La sesión trae cargadas la interfaz, el segundo operando después del mux, las seis
líneas one-hot del decodificador, las señales de control (`sub`, `swap`), las vías
internas (`x`, `yc`, `sum`, `shl`, `shr`) y la carga del registro. Es lo que hace
visible que la ALU está hecha con compuertas.

Un `.gtkw` guarda las rutas jerárquicas completas, así que **depende del nombre del
módulo del testbench y de la instancia**. Si el archivo que entregan usa otros
nombres, se abre `tb/calculadora_4bits_basico.gtkw` en un editor y se reemplaza
`calculadora_4bits_tb_basico` (y `dut`, si cambia) por los nuevos. La alternativa
sin editar nada es abrir el VCD solo y arrastrar las señales desde el árbol:

```bash
gtkwave calculadora_4bits_tb_basico.vcd
```

## Cobertura de simulación

| Testbench | Casos | Resultado |
|---|---|---|
| `adder4_tb` | 512 (barrido exhaustivo) | Sin errores |
| `shifter_tb` | 64 por dirección (exhaustivo) | Sin errores |
| `op_selector_tb` | 19 (subida, bajada, retención, prioridad, reset) | Sin errores |
| `alu_tb` | 2048 (8 op × 16 A × 16 B, exhaustivo) | Sin errores |
| `display_tb` | 107 (abs4, seg7, mux de fuente) | Sin errores |
| `debounce_tb` | 11 (prescaler, rebote, glitch, flanco) | Sin errores |
| `control_tb` | 79 (contadores, registro, FSM, one-hot) | Sin errores |
| `calculadora_4bits_tb` | 17 (interfaz de la evaluación) | Sin errores |
| `top_tb` | 33 (punta a punta, pulsaciones reales) | Sin errores |
| `demo_tb`, `alu_wave_tb` | editables, para la evaluación presencial | — |

`alu_tb` verifica además en cada caso que el decodificador mantenga la propiedad
one-hot, y que los códigos inválidos `110` y `111` dejen las seis salidas en 0.
`op_selector_tb` comprueba que el contador módulo 6 nunca alcance los códigos
ilegales `110` y `111`, y `control_tb` que la decodificación de estado
(`en_op`, `en_A`, `en_B`, `en_R`) se mantenga one-hot en todo momento.

### Los testbenches tampoco usan `if` ni `case`

La restricción se aplicó también a `tb/`. Ninguno de los **once testbenches
propios** usa `if`, `else` ni `case`. (El archivo
`tb/calculadora_4bits_tb_basico.sv` es de la cátedra, no nuestro, y sí los usa.)
Las técnicas:

| Necesidad | En vez de | Se usa |
|---|---|---|
| Contar errores | `if (a !== b) errores = errores + 1;` | `errores = errores + (a !== b);` — el operador `!==` entrega 1 o 0 |
| Elegir la referencia según la operación | `case (op)` | un lazo por operación, con su expresión escrita explícita |
| Guardar el primer caso que falla | asignación condicional | máscara `{N{bit}}` con bandera pegajosa |
| Imprimir el veredicto final | `if/else` | arreglo de strings indexado por la bandera de error |
| Detectar estado ilegal `110`/`111` | `if (op === 3'b110 \|\| ...)` | `ilegales = ilegales + (op[2] & op[1]);` |

Los operadores aritméticos (`+`, `-`, `<<`, `>>`) sí aparecen en los testbenches,
pero solo para calcular los valores de referencia: son justamente lo que le da
sentido al testbench, contrastar el diseño de compuertas contra la aritmética
nativa de Verilog. En `src/` no aparece ninguno.

`sim.bat` usa `if` de batch de Windows para despachar argumentos. Es un script de
consola, no Verilog, y no forma parte del diseño.

## Implementación en FPGA

```
sim.bat fpga        síntesis + place and route + bitstream (calc.bin)
sim.bat prog        programa la placa con iceprog
```

O con GNU Make: `make` y `make prog`.

Resultado de la síntesis (yosys 0.68 + nextpnr-ice40, iCE40 HX1K VQ100):

| Recurso | Uso | Disponible | % |
|---|---|---|---|
| Celdas lógicas (`ICESTORM_LC`) | 174 | 1280 | 13 % |
| Flip-flops (`SB_DFF`) | 56 | — | — |
| Pines (`SB_IO`) | 23 | 72 | 31 % |

La netlist son 166 `SB_LUT4` + 56 `SB_DFF`; el empaquetado a 174 celdas lógicas lo
hace nextpnr.

Frecuencia máxima **122,31 MHz** tras el ruteo, contra los 25 MHz del oscilador de
la placa (holgura de casi 5×). Sin latches inferidos ni lazos combinacionales.

## Cómo se usa en la placa

| Botón | Función |
|---|---|
| Superior izquierdo | Incrementar el valor |
| Inferior izquierdo | Disminuir el valor |
| Superior derecho | Confirmar y avanzar de estado |
| Inferior derecho | Usar el resultado anterior como segundo operando |

La calculadora recorre cuatro estados en ciclo, siempre avanzando con el botón
superior derecho:

| Estado | Se ingresa | Displays | LEDs |
|---|---|---|---|
| **S0** | Código de operación | `[-][-]` | Código de operación en LED 1–3 |
| **S1** | Operando A | Signo + magnitud | ídem |
| **S2** | Segundo operando | Signo + magnitud | ídem |
| **S3** | — (muestra el resultado) | Signo + magnitud | ídem + LED 4 encendido |

`LED_1` es el bit más significativo del código de operación. En S2, el botón
inferior derecho toma el resultado anterior como segundo operando y ejecuta de
inmediato. En S3 el botón superior derecho vuelve a S0.

El display izquierdo muestra el **signo** (guion encendido = negativo) y el
derecho la **magnitud** en hexadecimal (0 a 8). Los operandos conservan su valor
entre rondas; para poner el resultado en cero se usa la operación `000`.

## Polaridad

Todo el diseño trabaja en lógica positiva (`1` = encendido / apretado). Los dos
bloques de polaridad están marcados en `src/top.v`:

- **Botones y LEDs: activos en alto.** Entran por cuatro `buf`; si una placa
  resultara activa en bajo, se cambian por `not` y no hay que tocar nada más.
- **Displays de 7 segmentos: activos en bajo.** El 5261BG es de ánodo común
  —verificado en la placa—, así que las catorce salidas de segmento pasan por una
  compuerta `not` final. Es De Morgan aplicado en la salida y no obliga a rehacer
  ningún mapa de Karnaugh: la lógica interna sigue en lógica positiva.

Al arrancar deben verse **dos guiones**, uno en cada display.
