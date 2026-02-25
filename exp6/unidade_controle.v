module unidade_controle (
    input            clock,
    input            reset,
    input            iniciar,
    input            fim,
    input            igual,
    input            jogada,
    //input      modo,
    input      [1:0] configuracao,
    input            fim_seq,
    input            timeout,
    // output reg zeraC,
    output reg       zeraL,          // resta de rodadas
    output reg       zeraE,          //novas saidas zera o contador de end da memoria
    output reg       contaL,         // aumenta o nivel de dificuldade
    output reg       contaE,         // antigo contaC
    output reg       zeraTMR,        // zera o timer
    output reg       contaTMR,       // conta o tempod da jogada
    //  output reg contaC,
    output reg       zeraR,
    output reg       registraR,
    output reg       pronto,
    output reg       acertou,
    output reg       errou,
    //output reg modoR,
    output reg [1:0] configuracaoR,
    output reg [3:0] db_estado,
    output reg       escreveMem
);

  parameter inicial = 4'b0000;  // 0
  parameter inicializa_el = 4'b0001;  // 1
  parameter espera_jogada = 4'b0010;  // 2
  parameter inicia_seq = 4'b0011;  // 3 estado novo
  parameter registra = 4'b0100;  // 4
  parameter comparacao = 4'b0101;  // 5
  parameter proximo = 4'b0110;  // 6
  parameter ultima_jogada = 4'b0111;  // 7 estado novo
  parameter registra_nova = 4'b1000;  // estado para registrar a jogada e dar tempo para estabilizar os sinais de vao ser registraodos
  parameter grava_nova = 4'b1001;  // grava a nova jogada
  parameter fim_erro = 4'b1110;  // E
  parameter fim_acerto = 4'b1111;  // F

  reg [3:0] Eatual, Eprox;


  always @(posedge clock or posedge reset) begin
    if (reset) Eatual <= inicial;
    else Eatual <= Eprox;
  end

  always @(posedge clock or posedge reset) begin
    if (reset) begin
      configuracaoR <= 2'b00;
    end else if (iniciar && Eatual == inicial) begin
      configuracaoR <= configuracao;
    end
  end

  always @* begin
    case (Eatual)
      inicial:       Eprox = iniciar ? inicializa_el : inicial;
      inicializa_el: Eprox = inicia_seq;
      inicia_seq:    Eprox = espera_jogada;
      // NOVO: timeout encerra o jogo mesmo sem jogada
      espera_jogada: Eprox = timeout ? fim_erro : (jogada ? registra : espera_jogada);
      registra:      Eprox = comparacao;
      comparacao:    Eprox = (!igual) ? fim_erro : (fim_seq ? ultima_jogada : proximo);
      ultima_jogada: Eprox = fim ? fim_acerto : registra_nova;
      registra_nova: Eprox = jogada ? grava_nova : registra_nova;
      grava_nova:    Eprox = inicia_seq;
      proximo:       Eprox = espera_jogada;
      fim_erro:      Eprox = iniciar ? inicializa_el : fim_erro;
      fim_acerto:    Eprox = iniciar ? inicializa_el : fim_acerto;
      default:       Eprox = inicial;
    endcase
  end


  always @* begin


    zeraL = (Eatual == inicializa_el || Eatual == inicial) ? 1'b1 : 1'b0;
    zeraR = (Eatual == inicial) ? 1'b1 : 1'b0;
    registraR = (Eatual == registra || (Eatual== registra_nova)&&jogada) ? 1'b1 : 1'b0;//registra fica 1 quando tem jogada apenas
    // Avanca endereco durante a repeticao da sequencia (proximo)
    // e tambem apos a ultima comparacao valida para anexar a nova jogada
    // no proximo endereco da memoria.
    contaE = (Eatual == proximo || Eatual == ultima_jogada) ? 1'b1 : 1'b0;
    pronto = ((Eatual == fim_acerto) || (Eatual == fim_erro)) ? 1'b1 : 1'b0;
    acertou = (Eatual == fim_acerto) ? 1'b1 : 1'b0;
    errou = (Eatual == fim_erro) ? 1'b1 : 1'b0;
    zeraE = (Eatual == inicia_seq) ? 1'b1 : 1'b0;
    contaL = (Eatual == ultima_jogada) ? 1'b1 : 1'b0;
    // NOVO: controla timer (zera ao iniciar espera, conta enquanto espera)
    zeraTMR = (Eatual == inicia_seq) ? 1'b1 : 1'b0;
    contaTMR = ((Eatual == espera_jogada) && configuracaoR[1]) ? 1'b1 : 1'b0; //alterei por seguranca, vai que o conta causa um bug memso com o reset ativo
    //NOVOS : controle da ram
    escreveMem = (Eatual == grava_nova) ? 1'b1 : 1'b0;


    case (Eatual)
      inicial:       db_estado = 4'b0000;  // 0
      inicializa_el: db_estado = 4'b0001;  // 1
      espera_jogada: db_estado = 4'b0010;  // 2
      inicia_seq:    db_estado = 4'b0011;  // 3
      registra:      db_estado = 4'b0100;  // 4
      comparacao:    db_estado = 4'b0101;  // 5
      proximo:       db_estado = 4'b0110;  // 6
      ultima_jogada: db_estado = 4'b0111;  // 7
      registra_nova: db_estado = 4'b1000;  // 8
      grava_nova:    db_estado = 4'b1001;  // 9
      fim_acerto:    db_estado = 4'b1111;  // F
      fim_erro:      db_estado = 4'b1110;  // E

      default: db_estado = 4'b1110;  // E (erro)
    endcase
  end


endmodule

