`timescale 1ms/100us

module circuito_exp6_tb_desafio_trava_inicial;

    reg        clock, reset, jogar, inicial_sel;
    reg  [1:0] configuracao;
    reg  [3:0] botoes;

    wire [3:0] leds;
    wire       ganhou, perdeu, pronto;
    wire [3:0] db_estado;

    wire       s_zeraL, s_zeraE, s_contaL, s_contaE, s_zeraTMR, s_contaTMR, s_zeraR, s_registraR, s_escreveMem;
    wire [1:0] s_configuracaoR;
    wire       s_chavesIgualMemoria, s_enderecoIgualLimite, s_enderecoMenorOuIgualLimite;
    wire       s_fimL, s_fimE, s_fimTMR, s_jogada_feita;
    wire [3:0] s_db_contagem, s_db_memoria, s_db_limite, s_db_jogada;
    wire       s_db_tem_jogada;

    unidade_controle UC (
        .clock(clock), .reset(reset), .iniciar(jogar), .inicial_sel(inicial_sel), .fim(s_fimL),
        .igual(s_chavesIgualMemoria), .jogada(s_jogada_feita), .configuracao(configuracao),
        .fim_seq(s_enderecoIgualLimite), .timeout(s_fimTMR), .zeraL(s_zeraL), .zeraE(s_zeraE),
        .contaL(s_contaL), .contaE(s_contaE), .zeraTMR(s_zeraTMR), .contaTMR(s_contaTMR),
        .zeraR(s_zeraR), .registraR(s_registraR), .pronto(pronto), .acertou(ganhou),
        .errou(perdeu), .configuracaoR(s_configuracaoR), .db_estado(db_estado), .escreveMem(s_escreveMem)
    );

    fluxo_dados FD (
        .clock(clock), .reset(reset), .zeraE(s_zeraE), .zeraL(s_zeraL), .zeraTMR(s_zeraTMR),
        .limpaR(s_zeraR), .contaE(s_contaE), .contaL(s_contaL), .contaTMR(s_contaTMR),
        .registraR(s_registraR), .configuracaoR(s_configuracaoR), .conf_leds(1'b1),
        .botoes(botoes), .we(s_escreveMem), .chavesIgualMemoria(s_chavesIgualMemoria),
        .enderecoIgualLimite(s_enderecoIgualLimite), .enderecoMenorOuIgualLimite(s_enderecoMenorOuIgualLimite),
        .fimL(s_fimL), .fimE(s_fimE), .fimTMR(s_fimTMR), .jogada_feita(s_jogada_feita),
        .db_tem_jogada(s_db_tem_jogada), .db_configuracao(), .leds(leds), .db_contagem(s_db_contagem),
        .db_memoria(s_db_memoria), .db_limite(s_db_limite), .db_jogada(s_db_jogada)
    );

    localparam ST_ESPERA_INICIAL = 4'b1010;
    localparam ST_ESPERA_JOGADA  = 4'b0010;
    localparam ST_FIM_ERRO       = 4'b1110;

    always #0.5 clock = ~clock;  // 1 kHz

    task apertar_botao(input [3:0] valor);
    begin
        botoes = valor;
        #10;
        botoes = 4'b0000;
        #20;
    end
    endtask

    task espera_estado(input [3:0] estado, input integer limite_ms);
        integer t;
    begin
        t = 0;
        while ((db_estado !== estado) && (t < limite_ms)) begin
            #1; t = t + 1;
        end
        if (db_estado !== estado) begin
            $display("FALHA: timeout aguardando estado %b", estado);
            $finish;
        end
    end
    endtask

    integer t;
    reg viu_espera_inicial;

    initial begin
        $dumpfile("tb_desafio_trava_inicial.vcd");
        $dumpvars(0, circuito_exp6_tb_desafio_trava_inicial);

        clock = 0;
        reset = 1;
        jogar = 0;
        inicial_sel = 0;       // jogo 1 com inicial=0
        configuracao = 2'b00;
        botoes = 4'b0000;
        viu_espera_inicial = 1'b0;

        #2 reset = 0;
        #2 jogar = 1; #2 jogar = 0;

        espera_estado(ST_ESPERA_JOGADA, 20000);

        // Troca indevida durante jogo em andamento: deve ser ignorada.
        inicial_sel = 1'b1;

        // Erra de proposito para finalizar rapidamente jogo 1.
        apertar_botao(~s_db_memoria);

        t = 0;
        while ((db_estado !== ST_FIM_ERRO) && (t < 10000)) begin
            if (db_estado === ST_ESPERA_INICIAL) begin
                viu_espera_inicial = 1'b1;
            end
            #1;
            t = t + 1;
        end

        if (db_estado !== ST_FIM_ERRO) begin
            $display("FALHA: jogo 1 nao encerrou em erro no tempo esperado");
            $finish;
        end

        if (viu_espera_inicial) begin
            $display("FALHA: inicial_sel alterou o jogo em andamento");
            $finish;
        end

        // Novo jogo: agora inicial_sel=1 deve valer.
        #2 jogar = 1; #2 jogar = 0;
        espera_estado(ST_ESPERA_INICIAL, 5000);

        $display("SUCESSO: trava de inicial durante jogo validada.");
        #100;
        $finish;
    end

endmodule

