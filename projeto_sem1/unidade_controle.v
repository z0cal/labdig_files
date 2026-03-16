module unidade_controle (
    input clock,
    input reset,
    input start_pause,         // Botão de Start/Pause
    input fim_contagem,        // Sinal do FD indicando fim do 3-2-1
    input fim_tempo,           // Sinal do FD indicando fim da música/sessão
    input perdeu,              // Sinal do FD indicando limite de erros atingido
    output reg zera_timer,
    output reg conta_timer,
    output reg [3:0] db_estado // Depuração nos displays
);
ta
    parameter IDLE      = 4'b0000; // 0: Tela Inicial aguardando START
    parameter COUNTDOWN = 4'b0001; // 1: Preparação 3, 2, 1
    parameter PLAY      = 4'b0010; // 2: Execução do jogo
    parameter PAUSE     = 4'b0011; // 3: Jogo pausado
    parameter END_WIN   = 4'b0100; // 4: Vitória
    parameter END_LOSE  = 4'b0101; // 5: Derrota

    reg [3:0] Eatual, Eprox;

    always @(posedge clock or posedge reset) begin
        if (reset) Eatual <= IDLE;
        else Eatual <= Eprox;
    end

    always @* begin
        case (Eatual)
            IDLE:      Eprox = start_pause ? COUNTDOWN : IDLE;
            COUNTDOWN: Eprox = fim_contagem ? PLAY : COUNTDOWN;
            
            // Se não perdeu e o tempo acabou, ganha.
            PLAY:      Eprox = perdeu ? END_LOSE : 
                               (fim_tempo ? END_WIN : 
                               (start_pause ? PAUSE : PLAY));
                               
            PAUSE:     Eprox = start_pause ? PLAY : PAUSE;
            END_WIN:   Eprox = start_pause ? IDLE : END_WIN;
            END_LOSE:  Eprox = start_pause ? IDLE : END_LOSE;
            default:   Eprox = IDLE;
        endcase
    end

    // Sinais de controle do Fluxo de Dados
    always @* begin
        // Zera contadores no início e nos estados de fim
        zera_timer  = (Eatual == IDLE || Eatual == END_WIN || Eatual == END_LOSE) ? 1'b1 : 1'b0;
        
        // Conta o tempo apenas durante o 3-2-1 e o jogo rodando
        conta_timer = (Eatual == COUNTDOWN || Eatual == PLAY) ? 1'b1 : 1'b0;
        
        db_estado   = Eatual;
    end

endmodule