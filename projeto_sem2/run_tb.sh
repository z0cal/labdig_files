#!/bin/bash
# Compila e roda todos os testbenches com Icarus Verilog (iverilog).
# Uso: ./run_tb.sh
#      ./run_tb.sh tb_note_track   (roda so um TB)

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

run_tb() {
    local tb="$1"
    local src="$2"
    echo "────────────────────────────────────────"
    echo "Compilando: $tb"
    if iverilog -o "/tmp/${tb}.vvp" "${tb}.v" $src 2>&1; then
        echo "Executando: $tb"
        vvp "/tmp/${tb}.vvp"
        echo -e "${GREEN}Concluido: $tb${NC}"
    else
        echo -e "${RED}Falha na compilacao: $tb${NC}"
    fi
    echo ""
}

TARGET="${1:-all}"

case "$TARGET" in
    tb_uart_tx)
        run_tb tb_uart_tx "uart_tx.v"
        ;;
    tb_lfsr8)
        run_tb tb_lfsr8 "lfsr8.v"
        ;;
    tb_note_track)
        run_tb tb_note_track "note_track.v"
        ;;
    tb_debounce_pulse)
        run_tb tb_debounce_pulse "debounce_pulse.v"
        ;;
    tb_packet_sender)
        run_tb tb_packet_sender "uart_tx.v"
        ;;
    all)
        run_tb tb_uart_tx     "uart_tx.v"
        run_tb tb_lfsr8       "lfsr8.v"
        run_tb tb_note_track  "note_track.v"
        run_tb tb_debounce_pulse "debounce_pulse.v"
        run_tb tb_packet_sender "uart_tx.v"
        ;;
    *)
        echo "Uso: $0 [tb_uart_tx|tb_lfsr8|tb_note_track|tb_debounce_pulse|tb_packet_sender|all]"
        exit 1
        ;;
esac
