module fluxo_dados (
    input clock,
    input reset,
    
    // Sinais de controle vindos da UC para gerenciar a jogada
    input limpaR,              
    input registraR,           
    input zera_timer,          // NOVO: Para resetar o timer
    input conta_timer,         // NOVO: Para habilitar a contagem
    input [3:0] db_estado,     // NOVO: Para saber se esta no COUNTDOWN
    
    // Entradas fisicas
    input [4:0] botoes_raw,    // [4] = Start/Pause, [3:0] = Botoes do jogo
    
    // Saidas de dados e controle
    output [3:0] s_jogada,     // Jogada
    output jogada_feita,       // Indica aperto de nota
    output start_pulso,        // Indica aperto do start
    
    output fim_contagem,
    output fim_tempo,
    output perdeu
);

    // Separando os botões para facilitar a logica
    wire [3:0] botoes_trilha = botoes_raw[3:0]; // Botoes do jogo
    wire start = botoes_raw[4];                 // Botao de controle

    // Verifica se ha jogada
    wire s_tem_jogada = |botoes_trilha; 

    // Gera o pulso de 'jogada_feita' para avisar a UC
    edge_detector u_edge_jogada (
        .clock(clock),
        .reset(reset | limpaR),
        .sinal(s_tem_jogada),
        .pulso(jogada_feita)
    );

    // Temporizador de 3 segundos para o countdown (1kHz = 3000 contagens)
    contador_m #(.M(3000), .N(12)) timer_countdown (
        .clock   (clock),
        .zera_as (reset),
        .zera_s  (zera_timer),
        // Conta apenas quando a UC autoriza e estamos no estado COUNTDOWN (0001)
        .conta   (conta_timer && (db_estado == 4'b0001)),
        .Q       (),             // Valor de Q não é exportado nesta fase
        .fim     (fim_contagem), // Gera o sinal que faz a UC pular para PLAY
        .meio    ()
    );

    // Registrador que "salva" a jogada quando a UC manda (registraR)
    registrador_4 RegBotoes (
        .clock(clock),
        .clear(limpaR),
        .enable(registraR),
        .D(botoes_trilha),
        .Q(s_jogada)
    );

    // Detector de borda para o Start/Pause
    edge_detector u_edge_start (
        .clock(clock),
        .reset(reset),
        .sinal(start),
        .pulso(start_pulso)
    );

    // Sinais temporarios
	assign fim_tempo = botoes_raw[0] & botoes_raw[1]; 
	assign perdeu    = botoes_raw[2] & botoes_raw[3];
endmodule