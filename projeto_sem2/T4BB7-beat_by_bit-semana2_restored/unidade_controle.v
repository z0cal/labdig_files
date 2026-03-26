/*-----------------------------------------------------------------------
 * Arquivo   : unidade_controle.v
 * Projeto   : Beat by Bit - Semestre 2
 *-----------------------------------------------------------------------
 * Descricao : FSM do jogo. Mesmos estados do semestre 1.
 *             Agora perdeu e fim_tempo vem do fluxo_dados (nao mais
 *             placeholders). Adiciona saida game_active para habilitar
 *             a logica de jogo no fluxo_dados apenas durante PLAY.
 *-----------------------------------------------------------------------
 */

module unidade_controle (
    input  wire       clock,
    input  wire       reset,
    input  wire       start,        // start_pulso do FD
    input  wire       jogada,       // jogada_feita do FD
    input  wire       fim_contagem, // fim do countdown (3s)
    input  wire       fim_tempo,    // fim do jogo (60s) - vem do FD
    input  wire       perdeu,       // misses >= 10 - vem do FD

    output reg        registraR,
    output reg        limpaR,
    output reg        zera_timer,
    output reg        conta_timer,
    output reg        game_active,  // HIGH apenas em estado PLAY
    output reg [3:0]  db_estado
);

    localparam idle      = 4'b0000;
    localparam countdown = 4'b0001;
    localparam play      = 4'b0010;
    localparam pause     = 4'b0011;
    localparam end_win   = 4'b0100;
    localparam end_lose  = 4'b0101;

    reg [3:0] Eatual, Eprox;

    always @(posedge clock or posedge reset) begin
        if (reset) Eatual <= idle;
        else       Eatual <= Eprox;
    end

    always @* begin
        case (Eatual)
            idle:      Eprox = start ? countdown : idle;
            countdown: Eprox = fim_contagem ? play : countdown;
            play:      Eprox = perdeu    ? end_lose :
                               fim_tempo ? end_win  :
                               start     ? pause    : play;
            pause:     Eprox = start ? play : pause;
            end_win:   Eprox = start ? idle : end_win;
            end_lose:  Eprox = start ? idle : end_lose;
            default:   Eprox = idle;
        endcase
    end

    always @* begin
        zera_timer  = (Eatual == idle || Eatual == end_win || Eatual == end_lose) ? 1'b1 : 1'b0;
        conta_timer = (Eatual == countdown || Eatual == play) ? 1'b1 : 1'b0;
        game_active = (Eatual == play) ? 1'b1 : 1'b0;
        limpaR      = (Eatual == idle) ? 1'b1 : 1'b0;
        registraR   = (Eatual == play && jogada) ? 1'b1 : 1'b0;
        db_estado   = Eatual;
    end

endmodule
