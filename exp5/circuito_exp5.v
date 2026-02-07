module circuito_jogo_sequencias (
	input            clock,
    input            reset,
    input            jogar,
    input      [3:0] botoes,
    input            modo,
    output           ganhou,
    output           perdeu,
    output           pronto,
    output     [3:0] leds,
    output           timeout,
    output           db_igual,
    output     [6:0] db_contagem,
    output     [6:0] db_memoria,
    output     [6:0] db_estado,
    output     [6:0] db_jogadafeita,
    output           db_clock,
    output           db_iniciar,
    output           db_modo,
    output           db_tem_jogada
);

    wire        zeraC, contaC;
    wire        zeraR, registraR;
    wire        fimC;
    wire        igual, jogada;
    wire        s_db_modo;
    wire        modoR;

    wire [3:0]  s_db_contagem;
    wire [3:0]  s_db_memoria;
	wire [3:0]  db_jogada;
    wire [3:0]  s_db_estado;


    assign db_iniciar = jogar;
    assign db_igual   = igual;
    assign leds = db_jogada;
	assign db_clock = clock;
    assign db_modo = s_db_modo;


    unidade_controle u_uc (
        .clock      (clock),
        .reset      (reset),
        .iniciar    (jogar),
        .fim        (fimC),
		.igual  	(igual),
		.jogada     (jogada),
        .modo       (modo),
        .modoR      (modoR),
        .zeraC      (zeraC),
        .contaC     (contaC),
        .zeraR      (zeraR),
        .registraR  (registraR),
        .pronto     (pronto),
		.acertou	(ganhou),
		.errou		(perdeu),
        .db_estado  (s_db_estado)
    );

    fluxo_dados u_fd (
        .clock              (clock),
        .modoR              (modoR),
        .reset              (reset),
        .db_modo            (s_db_modo),
        .chaves             (chaves),
        .zeraR              (zeraR),
        .registraR          (registraR),
        .contaC             (contaC),
        .zeraC              (zeraC),
        .igual				(igual),
        .fimC               (fimC),
		.jogada_feita		(jogada),
		.db_tem_jogada		(db_tem_jogada),
        .db_contagem        (s_db_contagem),
		.db_memoria         (s_db_memoria),
		.db_jogada			(db_jogada)
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
		.hex (db_jogada),
        .seg (db_jogadafeita)
    );

    hexa7seg u_hex_est (
        .hex (s_db_estado),
        .seg (db_estado)
    );
    


endmodule
