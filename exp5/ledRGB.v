module ledRGB (
    input       conf_leds,
    input      [3:0] codigo,
    output reg [2:0] rgb
);

    
    always @* begin
        if (!conf_leds) begin
            rgb = 3'b000; // Apagado quando conf_leds=0
        end else begin
            case (codigo)
                4'b0001: rgb = 3'b010; // Vermelho
                4'b0010: rgb = 3'b100; // Azul
                4'b0100: rgb = 3'b011; // Amarelo (vermelho + verde)
                4'b1000: rgb = 3'b001; // Verde
                default: rgb = 3'b000; // Apagado
            endcase
        end
    end
endmodule
