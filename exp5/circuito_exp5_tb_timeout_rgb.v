`timescale 1ns/1ps

module circuito_exp5_tb_timeout_rgb;

  reg         clock;
  reg         reset;
  reg         jogar;
  reg  [3:0]  botoes;
  reg         modo;
  reg         conf_leds;

  wire        ganhou;
  wire        perdeu;
  wire        pronto;
  wire [3:0]  leds;
  wire [2:0]  db_rgb;
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
  wire [6:0]  db_limite;

  localparam integer CLK_PERIOD_NS = 1_000_000; // 1kHz => 1ms

  circuito_exp5 dut (
    .clock(clock),
    .reset(reset),
    .jogar(jogar),
    .botoes(botoes),
    .modo(modo),
    .conf_leds(conf_leds),
    .ganhou(ganhou),
    .perdeu(perdeu),
    .pronto(pronto),
    .leds(leds),
    .db_rgb(db_rgb),
    .timeout(timeout),
    .db_igual(db_igual),
    .db_contagem(db_contagem),
    .db_memoria(db_memoria),
    .db_estado(db_estado),
    .db_jogadafeita(db_jogadafeita),
    .db_clock(db_clock),
    .db_iniciar(db_iniciar),
    .db_modo(db_modo),
    .db_tem_jogada(db_tem_jogada),
    .db_limite(db_limite)
  );

  always #(CLK_PERIOD_NS/2) clock = ~clock;

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

  initial begin
    clock     = 1'b0;
    reset     = 1'b0;
    jogar     = 1'b0;
    botoes    = 4'b0000;
    modo      = 1'b0;
    conf_leds = 1'b1;

    reset = 1'b1;
    repeat (5) @(posedge clock);
    reset = 1'b0;

    start_game(1'b1);

    // Não pressiona nenhuma jogada: aguarda timeout (ContTMR = 3000 ciclos)
    repeat (3200) @(posedge clock);

    if (timeout !== 1'b1) begin
      $display("ERRO: timeout não ocorreu (t=%0t)", $time);
      $finish;
    end
    if (perdeu !== 1'b1) begin
      $display("ERRO: perdeu deveria estar 1 após timeout (t=%0t)", $time);
      $finish;
    end
    if (pronto !== 1'b1) begin
      $display("ERRO: pronto deveria estar 1 após timeout (t=%0t)", $time);
      $finish;
    end
    if (db_rgb !== 3'b000) begin
      $display("ERRO: db_rgb deveria estar apagado sem jogadas (t=%0t)", $time);
      $finish;
    end

    $display("Fim: pronto=%b ganhou=%b perdeu=%b timeout=%b", pronto, ganhou, perdeu, timeout);
    $finish;
  end

endmodule
