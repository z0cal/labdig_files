module unidade_controle (
    input clock,
    input reset,
    input btn_start_pause, // Botão de Start/Pause tratado
    input fim_contagem,    // Sinal do FD indicando fim do 3-2-1
    input fim_tempo,       // Sinal do FD indicando fim da música/sessão
    output reg zera_timer,
    output reg conta_timer,
    output reg [3:0] db_estado // Para depuração nos displays
);

    // Estados conforme Diagrama da FSM do planejamento
    parameter IDLE      = 4'b0000; // 0: Tela Inicial aguardando START
    parameter COUNTDOWN = 4'b0001; // 1: Preparação 3, 2, 1
    parameter PLAY      = 4'b0010; // 2: Execução da tarefa
    parameter PAUSE     = 4'b0011; // 3: Jogo pausado
    parameter END_ST    = 4'b0100; // 4: Resumo e encerramento

    reg [3:0] Eatual, Eprox;

    always @(posedge clock or posedge reset) begin
        if (reset) Eatual <= IDLE;
        else Eatual <= Eprox;
    end

    always @* begin
        case (Eatual)
            // Transições da FSM baseadas no storytelling do planejamento
            IDLE:      Eprox = btn_start_pause ? COUNTDOWN : IDLE;
            COUNTDOWN: Eprox = fim_contagem ? PLAY : COUNTDOWN;
            PLAY:      Eprox = fim_tempo ? END_ST : (btn_start_pause ? PAUSE : PLAY);
            PAUSE:     Eprox = btn_start_pause ? PLAY : PAUSE;
            END_ST:    Eprox = btn_start_pause ? IDLE : END_ST;
            default:   Eprox = IDLE;
        endcase
    end

    // Sinais de controle do Fluxo de Dados
    always @* begin
        zera_timer  = (Eatual == IDLE || Eatual == END_ST) ? 1'b1 : 1'b0;
        conta_timer = (Eatual == COUNTDOWN || Eatual == PLAY) ? 1'b1 : 1'b0;
        db_estado   = Eatual;
    end

endmodule