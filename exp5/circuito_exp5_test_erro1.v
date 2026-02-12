`timescale 1ns/1ps

module circuito_exp5_tb_modo0_erro_primeira;

  reg clock, reset, jogar, modo;
  reg [3:0] botoes;

  wire ganhou, perdeu, pronto, timeout;
  wire [3:0] leds;
  wire db_igual;
  wire [6:0] db_contagem, db_memoria, db_estado, db_jogadafeita;
  wire db_clock, db_iniciar, db_modo, db_tem_jogada;

  localparam integer CLK_PERIOD_NS = 1_000_000;

  circuito_exp5 dut (
    .clock(clock), .reset(reset), .jogar(jogar), .botoes(botoes), .modo(modo),
    .ganhou(ganhou), .perdeu(perdeu), .pronto(pronto), .leds(leds),
    .timeout(timeout), .db_igual(db_igual),
    .db_contagem(db_contagem), .db_memoria(db_memoria), .db_estado(db_estado),
    .db_jogadafeita(db_jogadafeita), .db_clock(db_clock),
    .db_iniciar(db_iniciar), .db_modo(db_modo), .db_tem_jogada(db_tem_jogada)
  );

  always #(CLK_PERIOD_NS/2) clock = ~clock;

  task automatic press(input [3:0] v);
    begin
      botoes = v;  repeat (2) @(posedge clock);
      botoes = 4'b0000; repeat (2) @(posedge clock);
    end
  endtask

  initial begin
    clock=0; reset=0; jogar=0; botoes=0; modo=0;

    reset=1; repeat(5) @(posedge clock); reset=0; repeat(5) @(posedge clock);

    modo=1'b0;
    jogar=1'b1; repeat(2) @(posedge clock); jogar=1'b0;
    repeat(5) @(posedge clock);

    // Errar de propósito (esperado ROM[0]=0001; envia 0010)
    press(4'b0010);

    repeat(50) @(posedge clock);
    $finish;
  end

  always @(posedge clock) if (pronto) begin
    $display("PRONTO: ganhou=%b perdeu=%b timeout=%b t=%0t", ganhou, perdeu, timeout, $time);
    #1 $finish;
  end

  initial begin
    #(2_000_000_000);
    $display("TIMEOUT SIM: pronto=%b ganhou=%b perdeu=%b timeout=%b", pronto, ganhou, perdeu, timeout);
    $finish;
  end

endmodule
