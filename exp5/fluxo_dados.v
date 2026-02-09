module fluxo_dados (
        input        clock,
        input        reset,
        input        zeraE,
        input        zeraL,
        input        zeraTMR,
        input        limpaR,
        input        contaE,
        input        contaL,
        input        contaTMR,
        input        registraR,
        input        modoR,
        input  [3:0] botoes,
        output       chavesIgualMemoria,
        output       enderecoIgualLimite,
        output       enderecoMenorOuIgualLimite,    
        output       fimL,
        output       fimE,
        output       fimTMR,
        output       jogada_feita,
        output       db_tem_jogada,
        output       db_modo,
        output [3:0] leds,
        output [3:0] db_contagem,
        output [3:0] db_memoria,
        output [3:0] db_limite,
        output [3:0] db_jogada
    ); 

        wire   [3:0] s_endereco;
        wire   [3:0] s_dado;
        wire   [3:0] s_jogada;
        wire   [3:0] s_limite;
        wire         s_tem_jogada;
        wire         s_enderecoMenorLimite;

        assign s_tem_jogada  = |botoes;
        assign db_tem_jogada = s_tem_jogada;
        assign db_contagem   = s_endereco;
        assign db_memoria    = s_dado;
        assign db_jogada     = s_jogada;
        assign db_modo       = modoR;
        assign db_limite     = s_limite;
        assign fimE          = (modoR == 1'b1 ) ? (s_endereco == 4'd3) : (s_endereco == 4'd15);
        assign fimL          = (modoR == 1'b1 ) ? (s_limite == 4'd3) : (s_limite == 4'd15);    
        assign leds          = s_jogada;
        assign enderecoMenorOuIgualLimite = s_enderecoMenorLimite | enderecoIgualLimite;
        
    edge_detector u_edge(
        .clock  (clock),
        .reset  (limpaR | zeraL),
        .pulso  (jogada_feita),
        .sinal  (s_tem_jogada)
    );
        
    contador_m #( .M(16), .N(4)) ContEnd (
        .clock      ( clock ),
        .zera_as    ( reset ),
        .zera_s     ( zeraE ),
        .conta      ( contaE ),
        .Q          ( s_endereco ),
        .fim        ( ),
        .meio       ( )
    );
    //cotnas quantas jogadas devem ser verificadas
    contador_m #( .M(16), .N(4)) ContLmt (
        .clock      ( clock ),
        .zera_as    ( reset ),
        .zera_s     ( zeraL ),
        .conta      ( contaL ),
        .Q          ( s_limite ),
        .fim        ( ),
        .meio       ( )
    );
    //limita a jogada a 3 segundos 
    contador_m #( .M(3000), .N(12)) ContTMR (
        .clock    ( clock ),
        .zera_as  ( reset ),
        .zera_s   ( zeraTMR ),
        .conta    ( contaTMR ),
        .Q        ( ),
        .fim      ( fimTMR ),
        .meio     ( )
    );


    sync_rom_16x4 MemJog (
        .clock    ( clock ),
        .address  ( s_endereco ),
        .data_out ( s_dado )
    );

    comparador_85 CompJog (
        .A      ( s_dado ),
        .B      ( s_jogada ),
        .ALBi   ( 1'b0 ),
        .AGBi   ( 1'b0 ),
        .AEBi   ( 1'b1 ),
        .ALBo   ( ),
        .AGBo   ( ),
        .AEBo   ( chavesIgualMemoria )
    );

    comparador_85 CompLmt (
        .A      ( s_limite ),
        .B      ( s_endereco ),
        .ALBi   ( 1'b0 ),
        .AGBi   ( 1'b0 ),
        .AEBi   ( 1'b1 ),
        .ALBo   ( ),
        .AGBo   ( enderecoMenorOuIgualLimite ),
        .AEBo   ( enderecoIgualLimite )
    );

    registrador_4 RegBotoes (
        .D      ( botoes ),
        .enable ( registraR ),
        .clear  ( limpaR ),
        .clock  ( clock ),
        .Q      ( s_jogada )
    );
    
endmodule
