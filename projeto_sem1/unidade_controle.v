module unidade_controle (
    input clock,
    input reset,
    input start,               // start_pulso do FD
    input jogada,              // Vem do jogada_feita do FD
    input fim_contagem,        // Sinal do FD indicando fim do 3-2-1      
    input fim_tempo,           // Sinal do FD indicando fim da música/sessão      
    input perdeu,              // Sinal do FD indicando limite de erros atingido         
    output reg registraR,      // Sinal para o FD salvar a jogada
    output reg limpaR,         // Sinal para o FD limpar o registrador
    output reg zera_timer,
    output reg conta_timer,
    output reg [3:0] db_estado // Depuração nos displays
);

    parameter idle      = 4'b0000; // 0: Aguardando START
    parameter countdown = 4'b0001; // 1: Preparação 3, 2, 1
    parameter play      = 4'b0010; // 2: Execução do jogo
    parameter pause     = 4'b0011; // 3: Jogo pausado
    parameter end_win   = 4'b0100; // 4: Vitoria
    parameter end_lose  = 4'b0101; // 5: Derrota

    reg [3:0] Eatual, Eprox;

    always @(posedge clock or posedge reset) begin
        if (reset) Eatual <= idle;
        else Eatual <= Eprox;
    end

    always @* begin
        case (Eatual)
            idle:      Eprox = start ? countdown : idle;
            countdown: Eprox = fim_contagem ? play : countdown;
            play:      Eprox = perdeu ? end_lose : 
                               (fim_tempo ? end_win : 
                               (start ? pause : play));
            pause:     Eprox = start ? play : pause;
            end_win:   Eprox = start ? idle : end_win;
            end_lose:  Eprox = start ? idle : end_lose;
            default:   Eprox = idle;
        endcase
    end

    always @* begin
        zera_timer  = (Eatual == idle || Eatual == end_win || Eatual == end_lose) ? 1'b1 : 1'b0;
        conta_timer = (Eatual == countdown || Eatual == play) ? 1'b1 : 1'b0;
        limpaR      = (Eatual == idle) ? 1'b1 : 1'b0;
        registraR   = (Eatual == play && jogada) ? 1'b1 : 1'b0;
        db_estado   = Eatual;
    end

endmodule