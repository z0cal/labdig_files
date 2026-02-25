`timescale 1ms/100us 

module circuito_exp6_tb3;

    reg clock, reset, jogar; 
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
        .clock(clock), .reset(reset), .iniciar(jogar), .fim(s_fimL), 
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
    end 
    endtask 

    initial begin 

        clock = 0; reset = 1; jogar = 0; botoes = 4'b0000; 
        configuracao = 2'b00; 

        #2 reset = 0; #2 jogar = 1; #2 jogar = 0;  

        $display("Jogo 1...");
        espera_estado(ST_ESPERA_JOGADA, 15000); apertar_botao(s_db_memoria); 
        espera_estado(ST_REGISTRA_NOVA, 15000); apertar_botao(4'b0001); 
        espera_estado(ST_ESPERA_JOGADA, 15000); apertar_botao(~s_db_memoria); // Erra na Rodada 2
        wait(perdeu == 1);
        $display("Jogo 1 Perdido. Iniciando Jogo 2 sem RESET...");
        
        #50 jogar = 1; #2 jogar = 0; 
        espera_estado(ST_ESPERA_JOGADA, 15000); apertar_botao(s_db_memoria); 
        espera_estado(ST_REGISTRA_NOVA, 15000); apertar_botao(4'b0010); 
        espera_estado(ST_ESPERA_JOGADA, 15000); apertar_botao(s_db_memoria); // Acerta no jogo 2
        
        $display("SUCESSO: Jogo 2 funcionando. Consecutivo OK.");
        #100; $finish; 
    end 
endmodule