module beat_by_bit (
    input clock,
    input reset,
    input [4:0] botoes,       
    output [6:0] db_estado,   // HEX0: Estado da FSM
    output [6:0] db_jogada,   // HEX1: Mostra qual botão foi lido (1, 2, 4, 8)
    output [4:0] leds_pulsos  // LEDs para depurar os pulsos de borda
);

    wire s_registraR, s_limpaR;
    wire s_jogada_feita, s_start_pulso;
    wire s_fim_contagem, s_fim_tempo, s_perdeu;
    wire s_zera_timer, s_conta_timer; // Fios adicionados para o timer
    wire [3:0] s_estado, s_valor_jogada;

    assign leds_pulsos = {s_start_pulso, 3'b000, s_jogada_feita};

    unidade_controle u_uc (
        .clock(clock),
        .reset(reset),
        .start(s_start_pulso),
        .jogada(s_jogada_feita),
        .fim_contagem(s_fim_contagem),
        .fim_tempo(s_fim_tempo),
        .perdeu(s_perdeu),
        .registraR(s_registraR),
        .limpaR(s_limpaR),
        .zera_timer(s_zera_timer),
        .conta_timer(s_conta_timer),
        .db_estado(s_estado)
    );

    fluxo_dados u_fd (
        .clock(clock),
        .reset(reset),
        .limpaR(s_limpaR),
        .registraR(s_registraR),
        .zera_timer(s_zera_timer),
        .conta_timer(s_conta_timer),
        .db_estado(s_estado),
        .botoes_raw(botoes),
        .s_jogada(s_valor_jogada),
        .jogada_feita(s_jogada_feita),
        .start_pulso(s_start_pulso),
        .fim_contagem(s_fim_contagem),
        .fim_tempo(s_fim_tempo),
        .perdeu(s_perdeu)
    );

    hexa7seg u_hex_est (
        .hex(s_estado),
        .seg(db_estado)
    );

    hexa7seg u_hex_jog (
        .hex(s_valor_jogada),
        .seg(db_jogada)
    );

endmodule