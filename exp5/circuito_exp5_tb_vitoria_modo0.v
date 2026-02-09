`timescale 1ns/1ps

module circuito_exp5_tb_vitoria_modo0;

  reg         clock;
  reg         reset;
  reg         jogar;
  reg  [3:0]  botoes;
  reg         modo;

  wire        ganhou;
  wire        perdeu;
  wire        pronto;
  wire [3:0]  leds;
  wire        timeout;

  wire        db_igual;
  wire [6:0]  db_contagem;
  wire [6:0]  db_memoria;
  wire [6:0]  db_estado;
  wire [6:0]  db_jogadafeita;
  wire        db_clock;
  wire        db_iniciar;
  wire        db_modo;
  wire        db_tem_jogada;

  localparam integer CLK_PERIOD_NS = 1_000_000;

  circuito_exp5 dut (
    .clock(clock),
    .reset(reset),
    .jogar(jogar),
    .botoes(botoes),
    .modo(modo),
    .ganhou(ganhou),
    .perdeu(perdeu),
    .pronto(pronto),
    .leds(leds),
    .timeout(timeout),
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

  always #(CLK_PERIOD_NS/2) clock = ~clock;

  task automatic press(input [3:0] v);
    begin
      botoes = v;
      repeat (5) @(posedge clock);
      botoes = 4'b0000;
      repeat (5) @(posedge clock);
    end
  endtask

  task automatic start_game(input m);
    begin
      modo  = m;
      @(posedge clock);
      jogar = 1'b1;
      repeat (2) @(posedge clock);
      jogar = 1'b0;
      repeat (5) @(posedge clock);
    end
  endtask

  reg [3:0] rom [0:15];
  integer round_len;
  integer k;

  initial begin
    clock  = 1'b0;
    reset  = 1'b0;
    jogar  = 1'b0;
    botoes = 4'b0000;
    modo   = 1'b0;

    rom[0]  = 4'b0001;
    rom[1]  = 4'b0010;
    rom[2]  = 4'b0100;
    rom[3]  = 4'b1000;
    rom[4]  = 4'b0100;
    rom[5]  = 4'b0010;
    rom[6]  = 4'b0001;
    rom[7]  = 4'b0001;
    rom[8]  = 4'b0010;
    rom[9]  = 4'b0010;
    rom[10] = 4'b0100;
    rom[11] = 4'b0100;
    rom[12] = 4'b1000;
    rom[13] = 4'b1000;
    rom[14] = 4'b0001;
    rom[15] = 4'b0100;

    reset = 1'b1;
    repeat (5) @(posedge clock);
    reset = 1'b0;

    start_game(1'b0);

    for (round_len = 1; round_len <= 16; round_len = round_len + 1) begin
      for (k = 0; k < round_len; k = k + 1) begin
        press(rom[k]);
      end
    end

    repeat (200) @(posedge clock);
    $display("Fim: pronto=%b ganhou=%b perdeu=%b timeout=%b", pronto, ganhou, perdeu, timeout);
    $finish;
  end

  always @(posedge clock) begin
    if (pronto) begin
      $display("PRONTO: ganhou=%b perdeu=%b timeout=%b (t=%0t)", ganhou, perdeu, timeout, $time);
      #1;
      $finish;
    end
  end

  initial begin
    #(500_000_000);
    $display("TIMEOUT DE SIMULACAO: pronto=%b ganhou=%b perdeu=%b timeout=%b", pronto, ganhou, perdeu, timeout);
    $finish;
  end

endmodule
