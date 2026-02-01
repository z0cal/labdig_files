

module circuito_exp3_desafio (
    input        clock,
    input        reset,
    input        iniciar,
    input  [3:0] chaves,
    output       pronto,
	output		  acertou,
	output		  errou,
    output        pronto,
    output reg [3:0] leds,
    output       db_igual,
    output       db_iniciar,
    output [6:0] db_contagem,
    output [6:0] db_memoria,
    output [6:0] db_chaves,
    output [6:0] db_estado,
    output [6:0] db_jogadafeita,
    output       db_clock,
    output       db_tem_jogada
);
    wire        sinal_pulso;
    wire        zeraC, contaC;
    wire        zeraR, registraR;
    wire        fimC;
    wire        igual;
    
    wire [3:0]  s_db_contagem;
    wire [3:0]  s_db_memoria;
    wire [3:0]  s_db_chaves;
    wire [3:0]  s_db_estado;

    assign db_iniciar = iniciar;
    assign db_igual   = igual;
    edge_detector u_edge(
        .clock      (clock),
        .reset      (reset),
        .pulso     (sinal_pulso),
        .sinal





    )
    exp3_unidade_controle u_uc (
        .clock      (clock),
        .reset      (reset),
        .iniciar    (iniciar),
        .fimC       (fimC),
		  .chavesIgualMemoria	(igual),
        .zeraC      (zeraC),
        .contaC     (contaC),
        .zeraR      (zeraR),
        .registraR  (registraR),
        .pronto     (pronto),
		  .acertou	  (acertou),
		  .errou			(errou),
        .db_estado  (s_db_estado)
    );

    exp3_fluxo_dados u_fd (
        .clock              (clock),
        .chaves             (chaves),
        .zeraR              (zeraR),
        .registraR          (registraR),
        .contaC             (contaC),
        .zeraC              (zeraC),
        .chavesIgualMemoria (igual),
        .fimC               (fimC),
        .db_contagem        (s_db_contagem),
        .db_chaves          (s_db_chaves),
        .db_memoria         (s_db_memoria)
    );

    hexa7seg u_hex_cont (
        .hex (s_db_contagem),
        .seg (db_contagem)
    );

    hexa7seg u_hex_mem (
        .hex (s_db_memoria),
        .seg (db_memoria)
    );

    hexa7seg u_hex_chv (
        .hex (s_db_chaves),
        .seg (db_chaves)
    );

    hexa7seg u_hex_est (
        .hex (s_db_estado),
        .seg (db_estado)
    );

endmodule