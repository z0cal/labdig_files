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
        wire         reset_cont;
        wire         fimLedTMR;
        reg          s_led_ativo;
        reg  [3:0]   s_led_codigo;
        reg          s_exibe_mem_pendente;
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
        assign reset_cont = (configuracaoR[1]) ? s_tem_jogada : 1'b1; //implementacao do modo com timer ou nao

    // Exibe a jogada por 2 segundos (clock de 1 kHz -> 2000 ciclos)
    // Eventos de exibicao:
    // - inicio de rodada: mostra a jogada atual da memoria (s_dado)
    // - jogada do jogador: mostra a jogada capturada (s_jogada)
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            s_led_ativo        <= 1'b0;
            s_led_codigo       <= 4'b0000;
            s_exibe_mem_pendente <= 1'b0;
            s_inicia_exibicao  <= 1'b0;
        end else if (limpaR) begin
            s_led_ativo        <= 1'b0;
            s_led_codigo       <= 4'b0000;
            s_exibe_mem_pendente <= 1'b0;
            s_inicia_exibicao  <= 1'b0;
        end else begin
            s_inicia_exibicao <= 1'b0;

            if (zeraE) begin
                s_exibe_mem_pendente <= 1'b1;
            end

            if (jogada_feita) begin
                s_led_ativo        <= 1'b1;
                s_led_codigo       <= s_jogada;
                s_exibe_mem_pendente <= 1'b0;
                s_inicia_exibicao  <= 1'b1;
            end else if (s_exibe_mem_pendente) begin
                s_led_ativo        <= 1'b1;
                s_led_codigo       <= s_dado;
                s_exibe_mem_pendente <= 1'b0;
                s_inicia_exibicao  <= 1'b1;
            end else if (s_led_ativo && fimLedTMR) begin
                s_led_ativo <= 1'b0;
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
    //limita a jogada a  5 segundos 
    contador_m #( .M(5000), .N(12)) ContTMR (
        .clock    ( clock ),
        .zera_as  ( reset_cont ),
        .zera_s   ( zeraTMR ),
        .conta    ( contaTMR ),
        .Q        ( ),
        .fim      ( fimTMR ),
        .meio     ( )
    );

    // temporizador da exibicao dos LEDs (2 segundos)
    contador_m #( .M(2000), .N(11)) ContLED (
        .clock      ( clock ),
        .zera_as    ( reset | limpaR ),
        .zera_s     ( s_inicia_exibicao ),
        .conta      ( s_led_ativo ),
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
