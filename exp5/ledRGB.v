module ledRGB (
    input      [3:0] codigo,
    output reg [2:0] rgb
);
    // rgb[2]=verde, rgb[1]=vermelho, rgb[0]=azul
    always @* begin
        case (codigo)
            4'b0001: rgb = 3'b010; // Vermelho
            4'b0010: rgb = 3'b001; // Azul
            4'b0100: rgb = 3'b110; // Amarelo (vermelho + verde)
            4'b1000: rgb = 3'b100; // Verde
            default: rgb = 3'b000; // Apagado
        endcase
    end
endmodule
