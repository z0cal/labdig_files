module fluxo_dados (
    input clock,
    input reset,
    input [4:0] botoes_raw, // 4 botões de trilha + 1 botão de Start/Pause
    output [4:0] botoes_pulso, // Sinal de 1 ciclo seguro para a UC e Lógica
    output fim_contagem,
    output fim_tempo
);

    wire [4:0] botoes_db; // Sinal após debounce

    // Bloco responsável por ler e tratar os 5 botões de entrada
    // Requisito da Semana 1: Debounce e Detector de Borda
    genvar i;
    generate
        for (i = 0; i < 5; i = i + 1) begin : btn_process
            // Módulo de debounce (sincronização + espera estável)
            debounce u_db (
                .clock(clock),
                .reset(reset),
                .in(botoes_raw[i]),
                .out(botoes_db[i])
            );

            // Gerador de pulso de evento discreto
            edge_detector u_edge (
                .clock(clock),
                .reset(reset),
                .sinal(botoes_db[i]),
                .pulso(botoes_pulso[i])
            );
        end
    endgenerate

    // TODO nas próximas semanas: Instanciar os contadores de tempo e 
    // avaliadores de acerto (hit window), combo, pontuação e memória de notas.
    assign fim_contagem = 1'b0; 
    assign fim_tempo = 1'b0;    

endmodule