`timescale 1ms/100us 

module circuito_exp6_tb1_4;

    reg clock, reset, jogar, inicial; 
    reg [1:0] configuracao; 
    reg [3:0] botoes; 

    wire [3:0] leds; 
    wire ganhou, perdeu, pronto; 
    wire [3:0] db_estado; 
     
    wire s_zeraL, s_zeraE, s_contaL, s_contaE, s_zeraTMR, s_contaTMR, s_zeraR, s_registraR, s_escreveMem; 
    wire [1:0] s_configuracaoR; 
    wire s_chavesIgualMemoria, s_enderecoIgualLimite, s_enderecoMenorOuIgualLimite; 
    wire s_fimL, s_fimE, s_fimTMR, s_jogada_feita; 
    wire [3:0] s_db_contagem, s_db_memoria, s_db_limite, s_db_jogada; 
    wire s_db_tem_jogada; 

    unidade_controle UC (
        .clock(clock), .reset(reset), .iniciar(jogar), .inicial_sel(inicial), .fim(s_fimL), 
        .igual(s_chavesIgualMemoria), .jogada(s_jogada_feita), .configuracao(configuracao), 
        .fim_seq(s_enderecoIgualLimite), .timeout(s_fimTMR), .zeraL(s_zeraL), .zeraE(s_zeraE), 
        .contaL(s_contaL), .contaE(s_contaE), .zeraTMR(s_zeraTMR), .contaTMR(s_contaTMR), 
        .zeraR(s_zeraR), .registraR(s_registraR), .pronto(pronto), .acertou(ganhou), 
        .errou(perdeu), .configuracaoR(s_configuracaoR), .db_estado(db_estado), .escreveMem(s_escreveMem)
    ); 

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

    localparam ST_ESPERA_JOGADA = 4'b0010; 
    localparam ST_REGISTRA_NOVA = 4'b1000; 
    localparam ST_ESPERA_INICIAL = 4'b1010;

    always #0.5 clock = ~clock; 

    task apertar_botao(input [3:0] valor); 
    begin 
        botoes = valor; #10; botoes = 4'b0000; #20;  
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
            $display("ERRO: timeout aguardando estado %b em t=%0t", estado, $time); 
            $finish; 
        end 
    end 
    endtask 

    integer i, j; 
    reg [3:0] nova_jogada; 

    initial begin  
        $dumpfile("jogo_tb1_4_vence.vcd");
        $dumpvars(0, circuito_exp6_tb1_4);

        clock = 0; reset = 1; jogar = 0; botoes = 4'b0000; 
        inicial = 1'b1;        // Ativa Desafio
        configuracao = 2'b01;  // Modo Demo 4 rodadas

        #2 reset = 0; 
        #2 jogar = 1; #2 jogar = 0;  

        // Jogada inicial do desafio (semente)
        espera_estado(ST_ESPERA_INICIAL, 15000); 
        apertar_botao(4'b0001); 
        $display("Semente 0001 registrada!");

        nova_jogada = 4'b0010; 

        for (i = 0; i < 4; i = i + 1) begin 
            $display("Iniciando Rodada %0d...", i + 1); 
            for (j = 0; j <= i; j = j + 1) begin 
                espera_estado(ST_ESPERA_JOGADA, 15000); 
                apertar_botao(s_db_memoria); 
            end 

            if (i < 3) begin // Na ultima rodada nao ha jogada nova
                espera_estado(ST_REGISTRA_NOVA, 15000); 
                apertar_botao(nova_jogada); 
                case (nova_jogada) 
                    4'b0001: nova_jogada = 4'b0010; 
                    4'b0010: nova_jogada = 4'b0100; 
                    4'b0100: nova_jogada = 4'b1000; 
                    default: nova_jogada = 4'b0001; 
                endcase 
            end 
            #20; 
        end 

        espera_estado(4'b1111, 20000); // fim_acerto 
        wait(ganhou == 1); 
        $display("SUCESSO: Jogador venceu as 4 rodadas!"); 
        #200; $finish; 
    end 
endmodule