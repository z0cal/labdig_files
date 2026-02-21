`timescale 1ms/100us

module circuito_exp6_tb1; // Nome solicitado pelo usuario

    // Sinais de estimulo
    reg clock, reset, jogar;
    reg [1:0] configuracao;
    reg [3:0] botoes;

    // Sinais de monitoramento
    wire [3:0] leds;
    wire ganhou, perdeu, pronto;
    wire [3:0] db_estado;
    
    // Wires de conexao (Evita erros de porta no compilador)
    wire s_zeraL, s_zeraE, s_contaL, s_contaE, s_zeraTMR, s_contaTMR, s_zeraR, s_registraR, s_escreveMem;
    wire [1:0] s_configuracaoR;
    wire s_chavesIgualMemoria, s_enderecoIgualLimite, s_enderecoMenorOuIgualLimite;
    wire s_fimL, s_fimE, s_fimTMR, s_jogada_feita;
    wire [3:0] s_db_contagem, s_db_memoria, s_db_limite, s_db_jogada;
    wire s_db_tem_jogada;

    // Instancia da Unidade de Controle (UC)
    unidade_controle UC (
        .clock(clock), .reset(reset), .iniciar(jogar), .fim(s_fimL),
        .igual(s_chavesIgualMemoria), .jogada(s_jogada_feita), .configuracao(configuracao),
        .fim_seq(s_enderecoIgualLimite), .timeout(s_fimTMR), .zeraL(s_zeraL), .zeraE(s_zeraE),
        .contaL(s_contaL), .contaE(s_contaE), .zeraTMR(s_zeraTMR), .contaTMR(s_contaTMR),
        .zeraR(s_zeraR), .registraR(s_registraR), .pronto(pronto), .acertou(ganhou),
        .errou(perdeu), .configuracaoR(s_configuracaoR), .db_estado(db_estado), .escreveMem(s_escreveMem)
    );

    // Instancia do Fluxo de Dados (FD)
    fluxo_dados FD (
        .clock(clock), .reset(reset), .zeraE(s_zeraE), .zeraL(s_zeraL), .zeraTMR(s_zeraTMR),
        .limpaR(s_zeraR), .contaE(s_contaE), .contaL(s_contaL), .contaTMR(s_contaTMR),
        .registraR(s_registraR), .configuracaoR(s_configuracaoR), .conf_leds(1'b0),
        .botoes(botoes), .we(s_escreveMem), .chavesIgualMemoria(s_chavesIgualMemoria),
        .enderecoIgualLimite(s_enderecoIgualLimite), .enderecoMenorOuIgualLimite(s_enderecoMenorOuIgualLimite),
        .fimL(s_fimL), .fimE(s_fimE), .fimTMR(s_fimTMR), .jogada_feita(s_jogada_feita),
        .db_tem_jogada(s_db_tem_jogada), .db_configuracao(), .leds(leds), .db_contagem(s_db_contagem),
        .db_memoria(s_db_memoria), .db_limite(s_db_limite), .db_jogada(s_db_jogada)
    );

    always #0.5 clock = ~clock; // Clock de 1kHz

    task apertar_botao(input [3:0] valor);
    begin
        botoes = valor;
        #10; // Mantem pressionado por 10ms
        botoes = 4'b0000;
        #20; 
    end
    endtask

    reg [3:0] gabarito [0:15]; 
    integer i, j;

    initial begin
        $dumpfile("jogo_vence_16.vcd");
        $dumpvars(0, circuito_exp6_tb1);

        // Define sequencia de cores (Vermelho, Azul, Amarelo, Verde...)
        for (i = 0; i < 16; i = i + 1) begin
            case (i % 4)
                0: gabarito[i] = 4'b0001; 1: gabarito[i] = 4'b0010;
                2: gabarito[i] = 4'b0100; 3: gabarito[i] = 4'b1000;
            endcase
        end

        clock = 0; reset = 1; jogar = 0; botoes = 4'b0000;
        configuracao = 2'b00; // Modo normal 16 rodadas

        #2 reset = 0;
        #2 jogar = 1; #2 jogar = 0; 

        for (i = 0; i < 16; i = i + 1) begin
            $display("Iniciando Rodada %0d...", i + 1);
            for (j = 0; j < i; j = j + 1) begin
                wait(db_estado == 4'b0010); // Estado espera_jogada
                apertar_botao(gabarito[j]);
            end
            wait(db_estado == 4'b1000); // Estado registra_nova
            apertar_botao(gabarito[i]);
            #50; 
        end

        wait(ganhou == 1); //
        $display("SUCESSO: Jogador venceu as 16 rodadas!");
        #200; $finish;
    end
endmodule