/*-----------------------------------------------------------------------
 * Arquivo   : projeto.v
 * Projeto   : Beat by Bit - Semestre 2
 *-----------------------------------------------------------------------
 * Descricao : Modulo top-level. Instancia UC, FD, packet_sender e
 *             displays de debug. Adiciona saida UART para PC.
 *-----------------------------------------------------------------------
 */

module beat_by_bit (
    input  wire        clock,
    input  wire        reset,
    input  wire [4:0]  botoes,
    output wire [6:0]  db_estado,    // HEX0: Estado da FSM
    output wire [6:0]  db_jogada,    // HEX1: Ultimo botao pressionado
    output wire [4:0]  leds_pulsos,  // LEDs de debug
    output wire        uart_tx_out   // TX serial para o PC (115200 baud)
);

    // Fios entre UC e FD
    wire s_registraR, s_limpaR;
    wire s_jogada_feita, s_start_pulso;
    wire s_fim_contagem, s_fim_tempo, s_perdeu;
    wire s_zera_timer, s_conta_timer, s_game_active;
    wire [3:0] s_estado, s_valor_jogada;

    // Fios de estado do jogo (FD -> packet_sender)
    wire [7:0] s_countdown_sec;
    wire [7:0] s_t0n0, s_t0n1, s_t0n2;
    wire [7:0] s_t1n0, s_t1n1, s_t1n2;
    wire [7:0] s_t2n0, s_t2n1, s_t2n2;
    wire [7:0] s_t3n0, s_t3n1, s_t3n2;
    wire [15:0] s_score;
    wire [7:0]  s_misses, s_combo;
    wire        s_frame_tick;

    assign leds_pulsos = {s_start_pulso, s_fim_contagem, s_fim_tempo, s_perdeu, s_jogada_feita};

    // ----------------------------------------------------------------
    // Unidade de Controle (FSM)
    // ----------------------------------------------------------------
    unidade_controle u_uc (
        .clock       (clock),
        .reset       (reset),
        .start       (s_start_pulso),
        .jogada      (s_jogada_feita),
        .fim_contagem(s_fim_contagem),
        .fim_tempo   (s_fim_tempo),
        .perdeu      (s_perdeu),
        .registraR   (s_registraR),
        .limpaR      (s_limpaR),
        .zera_timer  (s_zera_timer),
        .conta_timer (s_conta_timer),
        .game_active (s_game_active),
        .db_estado   (s_estado)
    );

    // ----------------------------------------------------------------
    // Fluxo de Dados (toda logica do jogo)
    // ----------------------------------------------------------------
    fluxo_dados u_fd (
        .clock        (clock),
        .reset        (reset),
        .limpaR       (s_limpaR),
        .registraR    (s_registraR),
        .zera_timer   (s_zera_timer),
        .conta_timer  (s_conta_timer),
        .game_active  (s_game_active),
        .db_estado    (s_estado),
        .botoes_raw   (botoes),
        .jogada_feita (s_jogada_feita),
        .start_pulso  (s_start_pulso),
        .fim_contagem (s_fim_contagem),
        .fim_tempo    (s_fim_tempo),
        .perdeu       (s_perdeu),
        .s_jogada     (s_valor_jogada),
        .countdown_sec(s_countdown_sec),
        .t0n0(s_t0n0), .t0n1(s_t0n1), .t0n2(s_t0n2),
        .t1n0(s_t1n0), .t1n1(s_t1n1), .t1n2(s_t1n2),
        .t2n0(s_t2n0), .t2n1(s_t2n1), .t2n2(s_t2n2),
        .t3n0(s_t3n0), .t3n1(s_t3n1), .t3n2(s_t3n2),
        .score         (s_score),
        .misses        (s_misses),
        .combo         (s_combo),
        .frame_tick_out(s_frame_tick)
    );

    // ----------------------------------------------------------------
    // Packet Sender (monta e envia pacote UART a cada frame)
    // ----------------------------------------------------------------
    packet_sender u_pkt (
        .clock        (clock),
        .reset        (reset),
        .frame_tick   (s_frame_tick),
        .game_state   (s_estado),
        .countdown_sec(s_countdown_sec),
        .t0n0(s_t0n0), .t0n1(s_t0n1), .t0n2(s_t0n2),
        .t1n0(s_t1n0), .t1n1(s_t1n1), .t1n2(s_t1n2),
        .t2n0(s_t2n0), .t2n1(s_t2n1), .t2n2(s_t2n2),
        .t3n0(s_t3n0), .t3n1(s_t3n1), .t3n2(s_t3n2),
        .score  (s_score),
        .misses (s_misses),
        .combo  (s_combo),
        .uart_tx_out(uart_tx_out)
    );

    // ----------------------------------------------------------------
    // Displays de debug
    // ----------------------------------------------------------------
    hexa7seg u_hex_est (
        .hex(s_estado),
        .seg(db_estado)
    );

    hexa7seg u_hex_jog (
        .hex(s_valor_jogada),
        .seg(db_jogada)
    );

endmodule
