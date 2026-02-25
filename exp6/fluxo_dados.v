module fluxo_dados (
        input        clock,
        input        reset,
        input        zeraE,
        input        zeraL,
        input        zeraTMR,
        input        limpaR,
        input        contaE,
        input        contaL,
        input        contaTMR,
        input        registraR,
        input   [1:0]configuracaoR,
        input        conf_leds,
        input  [3:0] botoes,
        input        we,
        output       chavesIgualMemoria,
        output       enderecoIgualLimite,
        output       enderecoMenorOuIgualLimite,    
        output       fimL,
        output       fimE,
        output       fimTMR,
        output       jogada_feita,
        output       db_tem_jogada,
        output [1:0] db_configuracao,
        output [3:0] leds,
        output [3:0] db_contagem,
        output [3:0] db_memoria,
        output [3:0] db_limite,
        output [3:0] db_jogada
    ); 

        wire   [3:0] s_endereco;
        wire   [3:0] s_dado;
        wire   [3:0] s_jogada;
        wire   [3:0] s_limite;
        wire         s_tem_jogada;
        wire         s_enderecoMenorLimite;
        wire         fimTMR_raw;
        wire         fimLedTMR;
        reg          s_led_ativo;
        reg          s_led_from_mem;
        reg  [3:0]   s_led_codigo;
        reg          s_exibe_mem_pendente;
        reg          s_exibe_mem_armed;
        reg          s_inicia_exibicao;
			
			
        assign s_tem_jogada  = |botoes;
        assign db_tem_jogada = s_tem_jogada;
        assign db_contagem   = s_endereco;
        assign db_memoria    = s_dado;
        assign db_jogada     = s_jogada;
        assign db_configuracao       = configuracaoR;
        assign db_limite     = s_limite;
        assign fimE          = (configuracaoR[0] == 1'b1 ) ? (s_endereco == 4'd3) : (s_endereco == 4'd15); //alterei de modoR para o sinal de configuracaoR
        assign fimL          = (configuracaoR[0] == 1'b1 ) ? (s_limite == 4'd3) : (s_limite == 4'd15);// esse tambem 
        assign leds          = s_led_ativo ? s_led_codigo : 4'b0000;
        assign enderecoMenorOuIgualLimite = s_enderecoMenorLimite | enderecoIgualLimite;
        assign fimTMR = configuracaoR[1] ? fimTMR_raw : 1'b0;

    // Exibicao de LEDs:
    // - primeira jogada da memoria (inicio do jogo): fica acesa por 2s e apaga
    // - jogada do jogador: permanece acesa ate uma nova jogada
    // Eventos de exibicao:
    // - inicio de rodada: mostra a jogada atual da memoria (s_dado)
    // - jogada do jogador: mostra a jogada pressionada (botoes)
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            s_led_ativo        <= 1'b0;
            s_led_from_mem     <= 1'b0;
            s_led_codigo       <= 4'b0000;
            s_exibe_mem_pendente <= 1'b0;
            s_exibe_mem_armed  <= 1'b0;
            s_inicia_exibicao  <= 1'b0;
        end else if (limpaR) begin
            s_led_ativo        <= 1'b0;
            s_led_from_mem     <= 1'b0;
            s_led_codigo       <= 4'b0000;
            s_exibe_mem_pendente <= 1'b0;
            s_exibe_mem_armed  <= 1'b0;
            s_inicia_exibicao  <= 1'b0;
        end else begin
            s_inicia_exibicao <= 1'b0;

            // Exibe a jogada da RAM apenas no inicio do jogo (primeira rodada).
            if (zeraE && (s_limite == 4'd0)) begin
                s_exibe_mem_pendente <= 1'b1;
                s_exibe_mem_armed    <= 1'b0;
            end

            if (jogada_feita) begin
                if (zeraE) begin
                    // Captura da jogada inicial (desafio): a exibicao de 2s
                    // sera feita em seguida pelo caminho da memoria.
                    s_led_ativo <= 1'b0;
                    s_led_from_mem <= 1'b0;
                end else begin
                    s_led_ativo        <= 1'b1;
                    s_led_from_mem     <= 1'b0;
                    // Exibe a jogada pressionada no instante do pulso.
                    // Usar 's_jogada' aqui pode mostrar o valor anterior,
                    // pois o registrador atualiza no mesmo clock.
                    s_led_codigo       <= botoes;
                end
                s_exibe_mem_pendente <= 1'b0;
                s_exibe_mem_armed  <= 1'b0;
                s_inicia_exibicao  <= 1'b0;
            end else if (s_exibe_mem_pendente && !s_exibe_mem_armed) begin
                // RAM sincrona: espera 1 ciclo para o dado do novo endereco
                // ficar valido antes de exibir a jogada da memoria.
                s_exibe_mem_armed <= 1'b1;
            end else if (s_exibe_mem_pendente && s_exibe_mem_armed) begin
                s_led_ativo        <= 1'b1;
                s_led_from_mem     <= 1'b1;
                s_led_codigo       <= s_dado;
                s_exibe_mem_pendente <= 1'b0;
                s_exibe_mem_armed  <= 1'b0;
                s_inicia_exibicao  <= 1'b1;
            end else if (s_led_ativo && s_led_from_mem && fimLedTMR) begin
                s_led_ativo <= 1'b0;
                s_led_from_mem <= 1'b0;
            end
        end
    end
        
    edge_detector u_edge(
        .clock  (clock),
        .reset  (limpaR | zeraL),
        .pulso  (jogada_feita),
        .sinal  (s_tem_jogada)
    );
        
    contador_m #( .M(16), .N(4)) ContEnd (
        .clock      ( clock ),
        .zera_as    ( reset ),
        .zera_s     ( zeraE ),
        .conta      ( contaE ),
        .Q          ( s_endereco ),
        .fim        ( ),
        .meio       ( )
    );
    //cotnas quantas jogadas devem ser verificadas
    contador_m #( .M(16), .N(4)) ContLmt (
        .clock      ( clock ),
        .zera_as    ( reset ),
        .zera_s     ( zeraL ),
        .conta      ( contaL ),
        .Q          ( s_limite ),
        .fim        ( ),
        .meio       ( )
    );
    // Limita a jogada a 5 segundos.
    // Reinicia no inicio de cada rodada e a cada jogada reconhecida.
    contador_m #( .M(5000), .N(13)) ContTMR (
        .clock    ( clock ),
        .zera_as  ( reset ),
        .zera_s   ( zeraTMR | jogada_feita ),
        .conta    ( contaTMR ),
        .Q        ( ),
        .fim      ( fimTMR_raw ),
        .meio     ( )
    );

    // temporizador da exibicao de jogada da memoria (2 segundos)
    contador_m #( .M(2000), .N(11)) ContLED (
        .clock      ( clock ),
        .zera_as    ( reset | limpaR ),
        .zera_s     ( s_inicia_exibicao ),
        .conta      ( s_led_ativo & s_led_from_mem ),
        .Q          ( ),
        .fim        ( fimLedTMR ),
        .meio       ( )
    );


    sync_ram_16x4_file MemJog (
        .clk    ( clock ),
        .addr  ( s_endereco ),
        .we     ( we ),
        .data   ( s_jogada),
        .q  ( s_dado )
    );

    comparador_85 CompJog (
        .A      ( s_dado ),
        .B      ( s_jogada ),
        .ALBi   ( 1'b0 ),
        .AGBi   ( 1'b0 ),
        .AEBi   ( 1'b1 ),
        .ALBo   ( ),
        .AGBo   ( ),
        .AEBo   ( chavesIgualMemoria )
    );

    comparador_85 CompLmt (
        .A      ( s_limite ),
        .B      ( s_endereco ),
        .ALBi   ( 1'b0 ),
        .AGBi   ( 1'b0 ),
        .AEBi   ( 1'b1 ),
        .ALBo   ( ),
        .AGBo   ( s_enderecoMenorLimite ),
        .AEBo   ( enderecoIgualLimite )
    );

    registrador_4 RegBotoes (
        .D      ( botoes ),
        .enable ( registraR ),
        .clear  ( limpaR ),
        .clock  ( clock ),
        .Q      ( s_jogada )
    );
    
endmodule
