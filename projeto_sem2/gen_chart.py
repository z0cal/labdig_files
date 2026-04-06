"""
gen_chart.py — Gerador de ROM para Beat by Bit (projeto_sem2)

Converte a partitura de "Concerning Hobbits" (Howard Shore, BPM=100)
em um arquivo .hex compatível com $readmemh do Quartus.

Uso:
    python gen_chart.py                   # gera concerning_hobbits.hex
    python gen_chart.py --preview         # mostra estatísticas sem salvar

Formato de saída (concerning_hobbits.hex):
    Uma linha por frame (a ~60fps), valor hex 2 dígitos (0x00–0x0F).
    Bit 0 = trilha 0, bit 1 = trilha 1, bit 2 = trilha 2, bit 3 = trilha 3.
    Total de linhas = ROM_DEPTH = 4428  (~73.8 s)
"""

import math
import argparse

# ─── Parâmetros de timing ──────────────────────────────────────────────────────

BPM           = 100
BEAT_MS       = 60_000 / BPM            # 600.0 ms por tempo

FPS           = 60
FRAME_MS      = 1000 / FPS              # ~16.667 ms por frame

HIT_Y         = 520                     # pixels (igual ao Verilog/Python)
NOTE_RADIUS   = 22
NOTE_SPEED    = 4                       # px/frame

# Tempo que a nota leva para cair do spawn até a hit zone:
LEAD_TIME_MS  = (HIT_Y + NOTE_RADIUS) / NOTE_SPEED * FRAME_MS
# = 542 / 4 * 16.667 = 2258.3 ms

TAIL_MS       = 3_000                   # tempo extra após a última nota

# Sequência completa da partitura: (nota, beats)
# 'R' = silêncio, notas em notação científica americana
CH_SEQ = [
    # ── Intro (compassos 1–2): sem melodia ─────────────────────────────────────
    ('R', 4), ('R', 4),

    # ── Tema A (compassos 3–6) ──────────────────────────────────────────────────
    ('A4', 1),  ('B4', 1),  ('D5', 1),  ('B4', 1),
    ('A4', 1.5),('G4', 0.5),('A4', 1),  ('R',  1),
    ('D5', 2),  ('A4', 0.5),('G4', 0.5),('F#4',1),
    ('G4', 2.5),('R',  0.5),('A4', 1),

    # ── Tema A' (compassos 7–10) ────────────────────────────────────────────────
    ('A4', 1),  ('B4', 1),  ('D5', 1),  ('B4', 1),
    ('A4', 1.5),('G4', 0.5),('F#4', 2),
    ('G4', 1),  ('A4', 1),  ('B4', 2),
    ('A4', 4),

    # ── Tema B (compassos 11–14) ────────────────────────────────────────────────
    ('D5', 1),  ('E5', 1),  ('F#5', 1), ('D5', 1),
    ('E5', 2),  ('C#5', 2),
    ('D5', 1),  ('C#5', 1), ('B4', 2),
    ('A4', 4),

    # ── Transição 2/4 (compassos 15–16) ────────────────────────────────────────
    ('D5', 1),  ('A4', 1),
    ('G4', 1),  ('F#4', 1),

    # ── Tema C (compassos 17–20) ────────────────────────────────────────────────
    ('E4', 1),  ('F#4', 1), ('G4', 2),
    ('A4', 2),  ('B4', 2),
    ('D5', 1),  ('C#5', 1), ('B4', 1),  ('A4', 1),
    ('G4', 2),  ('A4', 2),

    # ── Seção D (compassos 21–24) ───────────────────────────────────────────────
    ('B4', 1),  ('A4', 1),  ('G4', 2),
    ('F#4', 2), ('E4', 2),
    ('D5', 1),  ('D5', 1),  ('E5', 1),  ('F#5', 1),
    ('G5', 4),

    # ── Retorno Tema A (compassos 25–28) ───────────────────────────────────────
    ('A4', 1),  ('B4', 1),  ('D5', 1),  ('B4', 1),
    ('A4', 1.5),('G4', 0.5),('A4', 2),
    ('D5', 1),  ('C#5', 1), ('B4', 2),
    ('A4', 4),

    # ── Coda (compassos 29–30) ──────────────────────────────────────────────────
    ('D5', 2),  ('G4', 2),
    ('D4', 6),
]

TOTAL_BEATS   = sum(b for _, b in CH_SEQ)          # 118.0
TOTAL_MS      = TOTAL_BEATS * BEAT_MS + TAIL_MS    # 73 800 ms
ROM_DEPTH     = math.ceil(TOTAL_MS / FRAME_MS)     # 4428

MIN_SPACING_FRAMES = 21   # ≈ 350 ms mínimo entre notas na mesma lane

# ─── Mapeamento nota → lane ────────────────────────────────────────────────────

def note_to_lane(name: str) -> int:
    if name in ('D4', 'E4', 'F#4'):         return 0
    if name in ('G4', 'A4'):                return 1
    if name in ('B4', 'C#5', 'D5'):         return 2
    return 3   # E5, F#5, G5


# ─── Construção do chart ───────────────────────────────────────────────────────

def build_chart() -> list:
    """
    Retorna lista de (spawn_frame, lane) ordenada por frame.
    spawn_frame = frame no qual a FPGA deve ativar o spawn_en daquela trilha.
    """
    events = []   # (spawn_frame, lane)
    last_frame = [-1] * 4   # último spawn_frame por lane

    def try_add(hit_ms: float, lane: int):
        spawn_ms    = hit_ms - LEAD_TIME_MS
        spawn_frame = int(spawn_ms / FRAME_MS)
        if spawn_frame < 0:
            return
        if spawn_frame >= ROM_DEPTH:
            return
        # respeita espaçamento mínimo na mesma lane
        if spawn_frame - last_frame[lane] < MIN_SPACING_FRAMES:
            return
        events.append((spawn_frame, lane))
        last_frame[lane] = spawn_frame

    # Notas de aquecimento durante o intro (compassos 1–2)
    # Intro = beats 0–7 → hit nos beats 4,5,6,7 para encher a tela logo no início
    for i in range(4):
        hit_ms = (4 + i) * BEAT_MS
        try_add(hit_ms, i % 2)

    # Melodia principal
    t_ms = 0.0
    for note, beats in CH_SEQ:
        if note != 'R':
            # Apenas a partir do compasso 3 (beat 8 → 4800 ms)
            if t_ms >= 8 * BEAT_MS:
                try_add(t_ms, note_to_lane(note))
        t_ms += beats * BEAT_MS

    events.sort()
    return events


# ─── Geração do .hex ──────────────────────────────────────────────────────────

def build_rom(events: list) -> list:
    """
    Converte lista de (frame, lane) em array de ROM_DEPTH entradas de 4 bits.
    Cada frame pode ter até 4 bits setados (multi-spawn).
    """
    rom = [0] * ROM_DEPTH
    for frame, lane in events:
        rom[frame] |= (1 << lane)
    return rom


def write_hex(rom: list, path: str):
    with open(path, 'w') as f:
        for val in rom:
            f.write(f'{val:02X}\n')


def print_stats(events: list, rom: list):
    from collections import Counter
    lanes  = Counter(l for _, l in events)
    frames = [f for f, _ in events]

    print(f'-- Concerning Hobbits -- Estatisticas do Chart --')
    print(f'  BPM            : {BPM}')
    print(f'  Duração total  : {TOTAL_MS/1000:.1f} s')
    print(f'  ROM_DEPTH      : {ROM_DEPTH} frames')
    print(f'  LEAD_TIME_MS   : {LEAD_TIME_MS:.0f} ms')
    print(f'  Total de notas : {len(events)}')
    print(f'  Notas/s médio  : {len(events)/(TOTAL_MS/1000):.2f}')
    print(f'  Distribuição   : trilha 0={lanes[0]}  1={lanes[1]}  2={lanes[2]}  3={lanes[3]}')
    if frames:
        print(f'  Primeiro spawn : frame {frames[0]} ({frames[0]*FRAME_MS/1000:.2f} s)')
        print(f'  Último spawn   : frame {frames[-1]} ({frames[-1]*FRAME_MS/1000:.2f} s)')
    nonzero = sum(1 for v in rom if v)
    print(f'  Frames com spawn: {nonzero} / {ROM_DEPTH}')


# ─── Entrada ──────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Gerador de ROM para Beat by Bit')
    parser.add_argument('--output', default='concerning_hobbits.hex',
                        help='Arquivo de saída (padrão: concerning_hobbits.hex)')
    parser.add_argument('--preview', action='store_true',
                        help='Mostra estatísticas sem salvar o arquivo')
    args = parser.parse_args()

    events = build_chart()
    rom    = build_rom(events)

    print_stats(events, rom)

    if not args.preview:
        write_hex(rom, args.output)
        print(f'\nSalvo em: {args.output}  ({ROM_DEPTH} linhas)')
