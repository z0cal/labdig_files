module circuito_exp5 (
	input            clock,
    input            reset,
    input            jogar,
    input      [3:0] botoes,
    input            modo,
    input            conf_leds,
    output           ganhou,
    output           perdeu,
    output           pronto,
    output     [3:0] leds,
    output     [2:0] db_rgb,
    output           timeout,
    output           db_igual,
    output     [6:0] db_contagem,
    output     [6:0] db_memoria,
    output     [6:0] db_estado,
    output     [6:0] db_jogadafeita,
    output           db_clock,
    output           db_iniciar,
    output           db_modo,
    output           db_tem_jogada,
	 output    [6:0] db_limite
);

    wire        zeraE, contaE;
    wire        zeraL, contaL;
    wire        zeraTMR, contaTMR;
    wire        zeraR;
    wire        registraR;

    wire        chavesIgualMemoria;
    wire        enderecoIgualLimite;
    wire        fimL;
    wire        fimTMR;
    wire        jogada_feita;

    wire        modoR;

    wire [3:0]  s_db_contagem;
    wire [3:0]  s_db_memoria;
    wire [3:0]  s_db_estado;
    wire [3:0]  s_db_jogada;
	 wire [3:0]  s_db_limite;

	 
    assign db_iniciar   = jogar;
    assign db_igual     = chavesIgualMemoria;
	assign db_clock     = clock;
    assign db_modo      = modoR;

    unidade_controle u_uc (
        .clock      (clock),
        .reset      (reset),
        .iniciar    (jogar),
        .fim        (fimL),
		.igual  	(chavesIgualMemoria),
		.jogada     (jogada_feita),
        .modo       (modo),
        .fim_seq    (enderecoIgualLimite),
        .timeout    (fimTMR),
        .zeraL      (zeraL),
        .zeraE      (zeraE),
        .contaL     (contaL),
        .contaE     (contaE),
        .zeraTMR    (zeraTMR),
        .contaTMR   (contaTMR),
        .zeraR      (zeraR),
        .registraR  (registraR),
        .pronto     (pronto),
		.acertou	(ganhou),
		.errou		(perdeu),
        .modoR      (modoR),
        .db_estado  (s_db_estado)
    );

    fluxo_dados u_fd (
        .clock                      (clock),
        .reset                      (reset),
        .zeraE                      (zeraE),
        .zeraL                      (zeraL),
        .zeraTMR                    (zeraTMR),
        .limpaR                     (zeraR),
        .contaE                     (contaE),
        .contaL                     (contaL),
        .contaTMR                   (contaTMR),
        .registraR                  (registraR),
        .modoR                      (modoR),
        .botoes                     (botoes),
        .chavesIgualMemoria         (chavesIgualMemoria),
        .enderecoIgualLimite        (enderecoIgualLimite),
        .enderecoMenorOuIgualLimite (),
        .fimL                       (fimL),
        .fimE                       (),
        .fimTMR                     (fimTMR),
        .jogada_feita               (jogada_feita),
        .db_tem_jogada              (db_tem_jogada),
        .db_modo                    (db_modo),
        .leds                       (leds),
        .conf_leds                  (conf_leds),
        .db_contagem                (s_db_contagem),
        .db_memoria                 (s_db_memoria),
        .db_limite                  (s_db_limite),
        .db_jogada                  (s_db_jogada)
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
		.hex (s_db_jogada),
        .seg (db_jogadafeita)
    );

    hexa7seg u_hex_est (
        .hex (s_db_estado),
        .seg (db_estado)
    );

	 
    hexa7seg u_hex_lim (
        .hex (s_db_limite),
        .seg (db_limite)
    );

    ledRGB rgb(
        .conf_leds (conf_leds),
        .codigo    (s_db_jogada),
        .rgb       (db_rgb)
    );
	 
    assign timeout = fimTMR;

endmodule
