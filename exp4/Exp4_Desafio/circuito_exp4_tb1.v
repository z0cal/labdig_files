`timescale 1ns/1ns

module circuito_exp4_tb_cenario1;

    // sinais para conectar com o dut
    reg        clock_in   = 1;
    reg        reset_in   = 0;
    reg        iniciar_in = 0;
    reg  [3:0] chaves_in  = 4'b0000;

    wire        acertou_out;
    wire        errou_out;
    wire        pronto_out;
    wire [3:0]  leds_out;

    wire        db_igual_out;
    wire [6:0]  db_contagem_out;
    wire [6:0]  db_memoria_out;
    wire [6:0]  db_estado_out;
    wire [6:0]  db_jogadafeita_out;
    wire        db_clock_out;
    wire        db_iniciar_out;
    wire        db_tem_jogada_out;

    // configuracao do clock (1khz)
    parameter clockPeriod = 1_000_000; 

    // identificacao do caso de teste
    reg [31:0] caso = 0;

    // gerador de clock
    always #((clockPeriod / 2)) clock_in = ~clock_in;

    // instanciacao do dut conforme figura 8
    circuito_exp4 dut (
      .clock          ( clock_in    ),
      .reset          ( reset_in    ),
      .iniciar        ( iniciar_in  ),
      .chaves         ( chaves_in   ),
      .acertou        ( acertou_out ),
      .errou          ( errou_out   ),
      .pronto         ( pronto_out  ),
      .leds           ( leds_out    ),
      .db_igual       ( db_igual_out       ),
      .db_contagem    ( db_contagem_out    ),
      .db_memoria     ( db_memoria_out     ),
      .db_estado      ( db_estado_out      ),
      .db_jogadafeita ( db_jogadafeita_out ),
      .db_clock       ( db_clock_out       ),
      .db_iniciar     ( db_iniciar_out     ),    
      .db_tem_jogada  ( db_tem_jogada_out  )
    );

    // geracao dos estimulos conforme tabela 1
    initial begin
      $display("inicio da simulacao - cenario 1");

      // condicoes iniciais
      caso = 0;
      clock_in   = 1;
      reset_in   = 0;
      iniciar_in = 0;
      chaves_in  = 4'b0000;
      #clockPeriod;

      // 1. resetar circuito
      caso = 1;
      @(negedge clock_in);
      reset_in = 1;
      #(clockPeriod);
      reset_in = 0;

      // 2. aguardar alguns segundos
      caso = 2;
      #(10*clockPeriod);

      // 3. acionar sinal iniciar
      caso = 3;
      iniciar_in = 1;
      #(5*clockPeriod);
      iniciar_in = 0;
      #(10*clockPeriod);

      // --- inicio da repeticao das 16 jogadas ---

      // jogada 1: chave(0)
      caso = 4;
      @(negedge clock_in);
      chaves_in = 4'b0001;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 2: chave(1)
      caso = 5;
      @(negedge clock_in);
      chaves_in = 4'b0010;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 3: chave(2)
      caso = 6;
      @(negedge clock_in);
      chaves_in = 4'b0100;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 4: chave(3)
      caso = 7;
      @(negedge clock_in);
      chaves_in = 4'b1000;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 5: chave(2)
      caso = 8;
      @(negedge clock_in);
      chaves_in = 4'b0100;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 6: chave(1)
      caso = 9;
      @(negedge clock_in);
      chaves_in = 4'b0010;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 7: chave(0)
      caso = 10;
      @(negedge clock_in);
      chaves_in = 4'b0001;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 8: chave(0)
      caso = 11;
      @(negedge clock_in);
      chaves_in = 4'b0001;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 9: chave(1)
      caso = 12;
      @(negedge clock_in);
      chaves_in = 4'b0010;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 10: chave(1)
      caso = 13;
      @(negedge clock_in);
      chaves_in = 4'b0010;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 11: chave(2)
      caso = 14;
      @(negedge clock_in);
      chaves_in = 4'b0100;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 12: chave(2)
      caso = 15;
      @(negedge clock_in);
      chaves_in = 4'b0100;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 13: chave(3)
      caso = 16;
      @(negedge clock_in);
      chaves_in = 4'b1000;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 14: chave(3)
      caso = 17;
      @(negedge clock_in);
      chaves_in = 4'b1000;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 15: chave(0)
      caso = 18;
      @(negedge clock_in);
      chaves_in = 4'b0001;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // jogada 16: chave(2)
      caso = 19;
      @(negedge clock_in);
      chaves_in = 4'b0100;
      #(10*clockPeriod);
      chaves_in = 4'b0000;
      #(10*clockPeriod);

      // finalizacao
      caso = 99;
      #100;
      $display("fim da simulacao");
      $stop;
    end

endmodule
