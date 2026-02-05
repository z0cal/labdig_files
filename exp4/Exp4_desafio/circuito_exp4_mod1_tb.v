`timescale 1ns/1ps

module tb_circuito_exp4_modo1;

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

  circuito_exp4_desafio2 dut (
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

  initial clock = 1'b0;
  always #5 clock = ~clock;

  task automatic joga(input [3:0] v);
  begin
    chaves = v;
    repeat (3) @(posedge clock);
    chaves = 4'b0000;
    repeat (3) @(posedge clock);
  end
  endtask

  reg [3:0] seq [0:3];
  integer i;

  initial begin
    seq[0] = 4'b0001;
    seq[1] = 4'b0010;
    seq[2] = 4'b0100;
    seq[3] = 4'b1000;

    reset   = 1'b1;
    iniciar = 1'b0;
    chaves  = 4'b0000;
    modo    = 1'b1;

    repeat (3) @(posedge clock);
    reset = 1'b0;

    @(posedge clock);
    iniciar = 1'b1;
    @(posedge clock);
    iniciar = 1'b0;

    repeat (3) @(posedge clock);
    modo = 1'b0;

    for (i = 0; i < 4; i = i + 1) begin
      joga(seq[i]);
    end
  end

  initial begin
    @(posedge pronto);
    #20;
    $finish;
  end

  initial begin
    repeat (2000) @(posedge clock);
    $finish;
  end

endmodule
