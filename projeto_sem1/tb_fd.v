`timescale 1ms/100us 

module tb_fd;

    // Entradas
    reg clock, reset;
    reg [4:0] botoes_raw;

    // Fios de Interconexao
    wire [3:0] s_jogada;
    wire jogada_feita, start_pulso, fim_contagem, fim_tempo, perdeu;
    wire registraR, limpaR, zera_timer, conta_timer;
    wire [3:0] db_estado;

    // Instancia do Fluxo de Dados
    fluxo_dados ufdt (
        .clock(clock),
        .reset(reset),
        .limpaR(limpaR),        
        .registraR(registraR),
        .zera_timer(zera_timer),
        .conta_timer(conta_timer),
        .db_estado(db_estado),
        .botoes_raw(botoes_raw),
        .s_jogada(s_jogada),
        .jogada_feita(jogada_feita),     
        .start_pulso(start_pulso), 
        .fim_contagem(fim_contagem),
        .fim_tempo(fim_tempo),
        .perdeu(perdeu)
    );

    // Instancia da Unidade de Controle
    unidade_controle uuct (
        .clock(clock),
        .reset(reset),
        .start(start_pulso),     
        .jogada(jogada_feita),      
        .fim_contagem(fim_contagem),
        .fim_tempo(fim_tempo),
        .perdeu(perdeu),
        .registraR(registraR),     
        .limpaR(limpaR),           
        .zera_timer(zera_timer),
        .conta_timer(conta_timer),
        .db_estado(db_estado)      
    );

    // Gerador de Clock (1kHz = T de 1ms. Como a escala base é 1ms, #0.5 faz um pulso de 0.5ms)
    always #0.5 clock = ~clock;

    // Procedimento de Teste
    initial begin
        $display("Iniciando Simulacao...");
        clock = 0; reset = 1; botoes_raw = 0;
        
        #2; reset = 0; // Vai para IDLE (estado 0)
        #2;

        // Passo 1: Iniciar o Jogo
        $display("Pressionando Botao START...");
        botoes_raw[4] = 1; #1; botoes_raw[4] = 0;
        // O estado muda para COUNTDOWN

        $display("Aguardando os 3 segundos do COUNTDOWN...");
        #3005; // Aguarda mais de 3000 ms (3 segundos reais) para o contador terminar

        // Passo 2: Simular Jogada (Botão 1)
        $display("Apertando Botao 1 (Gameplay) no estado PLAY...");
        botoes_raw[1] = 1; #2; botoes_raw[1] = 0;

        #10;
        $display("Fim da simulacao.");
        $stop;
    end
endmodule