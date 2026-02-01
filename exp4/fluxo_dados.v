    module fluxo_dados (
        input        clock,
        input        zeraC,
        input        contaC,
        input        zeraR,
        input        registraR,
        input  [3:0] chaves,
        output       igual,
        output       fimC,
        output       jogada_feita,
        output       db_tem_jogada,
        output [3:0] db_contagem,
        output [3:0] db_memoria,
        output [3:0] db_jogada
    ); 

        wire   [3:0] s_endereco;
        wire   [3:0] s_dado;
        wire   [3:0] s_chaves;
        wire         s_tem_jogada;

        assign s_tem_jogada  = |chaves;
        assign db_tem_jogada = s_tem_jogada;
        assign db_contagem   = s_endereco;
        assign db_memoria    = s_dado;
        assign db_jogada     = s_chaves;
        
    edge_detector u_edge(
        .clock  (clock),
        .reset  (zeraR | zeraC),
        .pulso  (jogada_feita),
        .sinal  (s_tem_jogada)
    );
        
    contador_163 contadorJ (
        .clock  ( clock ),
        .clr    ( ~zeraC ),
        .ld     ( 1'b1 ),
        .enp    ( contaC ),
        .ent    ( 1'b1 ),
        .D      ( 4'b0000 ),
        .Q      ( s_endereco ),
        .rco    ( fimC )
    ); 
    
    sync_rom_16x4 memoria (
        .clock    ( clock ),
        .address  ( s_endereco ),
        .data_out ( s_dado )
    );

    comparador_85 comparador (
        .A      ( s_dado ),
        .B      ( s_chaves ),
        .ALBi   ( 1'b0 ),
        .AGBi   ( 1'b0 ),
        .AEBi   ( 1'b1 ),
        .ALBo   ( ),
        .AGBo   ( ),
        .AEBo   ( igual )
    );

    registrador_4 registradorJ (
        .D      ( chaves ),
        .enable ( registraR ),
        .clear  ( zeraR ),
        .clock  ( clock ),
        .Q      ( s_chaves )
    );

 endmodule
