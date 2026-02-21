`timescale 1ns/1ps

module circuito_exp5_tb_conf_leds_toggle;

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

  function automatic [2:0] map_rgb(input [3:0] code);
    begin
      case (code)
        4'b0001: map_rgb = 3'b010; // Vermelho
        4'b0010: map_rgb = 3'b100; // Azul
        4'b0100: map_rgb = 3'b011; // Amarelo
        4'b1000: map_rgb = 3'b001; // Verde
        default: map_rgb = 3'b000; // Apagado
      endcase
    end
  endfunction

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

  task automatic press(input [3:0] v);
    begin
      botoes = v;
      repeat (5) @(posedge clock);
      botoes = 4'b0000;
      repeat (5) @(posedge clock);
    end
  endtask

  task automatic expect_leds_only(input [3:0] v);
    integer i;
    begin
      // espera até o registrador de jogada refletir o valor (latência interna)
      for (i = 0; i < 20; i = i + 1) begin
        if (leds === v) begin
          i = 20;
        end else begin
          @(posedge clock);
        end
      end
      if (leds !== v) begin
        $display("ERRO: leds esperado=%b obtido=%b (t=%0t)", v, leds, $time);
        $finish;
      end
      if (db_rgb !== 3'b000) begin
        $display("ERRO: conf_leds=0 deve apagar db_rgb. db_rgb=%b (t=%0t)", db_rgb, $time);
        $finish;
      end
    end
  endtask

  task automatic expect_rgb_only(input [3:0] v);
    reg [2:0] expected;
    integer i;
    begin
      expected = map_rgb(v);
      // espera até a saída RGB refletir o valor (latência interna)
      for (i = 0; i < 20; i = i + 1) begin
        if (db_rgb === expected) begin
          i = 20;
        end else begin
          @(posedge clock);
        end
      end
      if (db_rgb !== expected) begin
        $display("ERRO: db_rgb esperado=%b obtido=%b (t=%0t)", expected, db_rgb, $time);
        $finish;
      end
      if (leds !== 4'b0000) begin
        $display("ERRO: conf_leds=1 deve apagar leds. leds=%b (t=%0t)", leds, $time);
        $finish;
      end
    end
  endtask

  initial begin
    clock     = 1'b0;
    reset     = 1'b0;
    jogar     = 1'b0;
    botoes    = 4'b0000;
    modo      = 1'b0;
    conf_leds = 1'b0;

    reset = 1'b1;
    repeat (5) @(posedge clock);
    reset = 1'b0;

    start_game(1'b1);

    // 1) conf_leds=0 -> saída em leds
    conf_leds = 1'b0;
    press(4'b0001);
    expect_leds_only(4'b0001);

    // 2) alterna para RGB -> leds apagam, db_rgb ativo
    conf_leds = 1'b1;
    press(4'b0010);
    expect_rgb_only(4'b0010);

    // 3) alterna de volta para leds
    conf_leds = 1'b0;
    press(4'b0100);
    expect_leds_only(4'b0100);

    repeat (50) @(posedge clock);
    $display("Fim: pronto=%b ganhou=%b perdeu=%b timeout=%b", pronto, ganhou, perdeu, timeout);
    $finish;
  end

endmodule
