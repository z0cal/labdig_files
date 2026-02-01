module exp3_unidade_controle (
    input      clock,
    input      reset,
    input      iniciar,
    input      fimC,
	input		chavesIgualMemoria,
    input      jogada,
    output reg zeraC,
    output reg contaC,
    output reg zeraR,
    output reg registraR,
    output reg pronto,
	output reg acertou,
	output reg errou,
    output reg [3:0] db_estado
);

    // Define estados
    parameter inicial    = 4'b0000;  // 0
    parameter preparacao = 4'b0001;  // 1
    parameter espera_jogada = 4'b0010; // 2
    parameter registra   = 4'b0100;  // 4
    parameter comparacao = 4'b0101;  // 5
    parameter proximo    = 4'b0110;  // 6
	 parameter fim_erro	 = 4'b1110;  // E
    parameter fim_acerto = 4'b1111;  // F
    // Variaveis de estado
    reg [3:0] Eatual, Eprox;

    // Memoria de estado
    always @(posedge clock or posedge reset) begin
        if (reset)
            Eatual <= inicial;
        else
            Eatual <= Eprox;
    end

    // Logica de proximo estado
    always @* begin
        case (Eatual)
            inicial:     Eprox = iniciar ? preparacao : inicial;
            preparacao:  Eprox = espera_jogada;
            espera_jogada: Eprox= jogada ? registra: espera_jogada;
            registra:    Eprox = comparacao;
            comparacao:  Eprox = (!chavesIgualMemoria) ? fim_erro : 
									(fimC ? fim_acerto : proximo);
            proximo:     Eprox = espera_jogada;
            fim_erro:   Eprox = iniciar ? preparacao : fim_erro;
            fim_acerto: Eprox = iniciar ? preparacao : fim_acerto;
            default:     Eprox = inicial;
        endcase
    end

    // Logica de saida (maquina Moore)
    always @* begin
        zeraC     = (Eatual == preparacao) ? 1'b1 : 1'b0;
        zeraR     = (Eatual == inicial) ? 1'b1 : 1'b0;
        registraR = (Eatual == registra) ? 1'b1 : 1'b0;
        contaC    = (Eatual == proximo) ? 1'b1 : 1'b0;
        pronto    = ((Eatual == fim_acerto) || (Eatual == fim_erro)) ? 1'b1 : 1'b0;
		  
		  acertou	= (Eatual == fim_acerto) ? 1'b1 : 1'b0;
		  errou		= (Eatual == fim_erro) ? 1'b1 : 1'b0;

        // Saida de depuracao (estado)
        case (Eatual)
            inicial:     db_estado = 4'b0000;  // 0
            preparacao:  db_estado = 4'b0001;  // 1
            espera_jogada: db_estado=4'b0010; // 2
            registra:    db_estado = 4'b0100;  // 4
            comparacao:  db_estado = 4'b0101;  // 5
            proximo:     db_estado = 4'b0110;  // 6
				
            fim_acerto:         db_estado = 4'b1111;  // F
			fim_erro:			  db_estado = 4'b1110; // E
				
            default:     db_estado = 4'b1110;  // E (erro)
        endcase
    end

endmodule