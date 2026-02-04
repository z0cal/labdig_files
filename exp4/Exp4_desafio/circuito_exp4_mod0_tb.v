`timescale 1ns/1ps

module tb_circuito_exp4_modo0;

  reg         clock;
  reg         reset;
  reg         iniciar;
  reg  [3:0]  chaves;
  reg         modo;

  wire        acertou;
  wire        errou;
  wire        pronto;
  wire [3:0]  leds;
  wire        db_igual;
  wire [6:0]  db_contagem;
  wire [6:0]  db_memoria;
  wire [6:0]  db_estado;
  wire [6:0]  db_jogadafeita;
  wire        db_clock;
  wire        db_iniciar;
  wire        db_modo;
  wire        db_tem_jogada;

  circuito_exp4 dut (
    .clock(clock),
    .reset(reset),
    .iniciar(iniciar),
    .chaves(chaves),
    .modo(modo),
    .acertou(acertou),
    .errou(errou),
    .pronto(pronto),
    .leds(leds),
    .db_igual(db_igual),
    .db_contagem(db_contagem),
    .db_memoria(db_memoria),
    .db_estado(db_estado),
    .db_jogadafeita(db_jogadafeita),
    .db_clock(db_clock),
    .db_iniciar(db_iniciar),
    .db_modo(db_modo),
    .db_tem_jogada(db_tem_jogada)
  );

  // clock 100MHz (10ns)
  initial clock = 1'b0;
  always #5 clock = ~clock;

  task automatic joga(input [3:0] v);
  begin
    chaves = v;
    repeat (3) @(posedge clock);  // garante: pulso do edge + captura no registrador
    chaves = 4'b0000;
    repeat (3) @(posedge clock);  // deixa a UC passar por comparacao/proximo/espera
  end
  endtask

  reg [3:0] seq [0:15];
  integer i;

  initial begin
    // sequencia da sync_rom_16x4 (enderecos 0..15)
    seq[0]  = 4'b0001;
    seq[1]  = 4'b0010;
    seq[2]  = 4'b0100;
    seq[3]  = 4'b1000;
    seq[4]  = 4'b0100;
    seq[5]  = 4'b0010;
    seq[6]  = 4'b0001;
    seq[7]  = 4'b0001;
    seq[8]  = 4'b0010;
    seq[9]  = 4'b0010;
    seq[10] = 4'b0100;
    seq[11] = 4'b0100;
    seq[12] = 4'b1000;
    seq[13] = 4'b1000;
    seq[14] = 4'b0001;
    seq[15] = 4'b0100;

    reset   = 1'b1;
    iniciar = 1'b0;
    chaves  = 4'b0000;
    modo    = 1'b0; // MODO = 0 (fim em 15)

    repeat (3) @(posedge clock);
    reset = 1'b0;

    @(posedge clock);
    iniciar = 1'b1;
    @(posedge clock);
    iniciar = 1'b0;

    repeat (3) @(posedge clock);

    for (i = 0; i < 16; i = i + 1) begin
      joga(seq[i]);
    end

    wait (pronto == 1'b1);

    if (acertou && !errou) $display("OK: modo=0 terminou em ACERTO.");
    else                  $display("ERRO: modo=0 nao terminou como esperado (acertou=%b errou=%b).", acertou, errou);

    repeat (2) @(posedge clock);
    $finish;
  end

endmodule
