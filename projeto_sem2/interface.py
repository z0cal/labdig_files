"""
Beat by Bit - Semestre 2
Renderer puro: recebe pacotes da FPGA via UART e renderiza o jogo.
Nenhuma logica de jogo aqui — tudo roda na FPGA (Verilog).

Protocolo UART (115200 baud, 8N1):
  Pacote de 20 bytes a ~60fps:
    [0]  0x55          marcador de inicio
    [1]  state         0=IDLE 1=COUNTDOWN 2=PLAY 3=PAUSE 4=WIN 5=LOSE
    [2]  countdown_sec 3,2,1,0
    [3-5]  trilha 0 — ages das 3 notas (0xFF = vazio)
    [6-8]  trilha 1
    [9-11] trilha 2
    [12-14]trilha 3
    [15] score high byte
    [16] score low byte
    [17] misses (0-10)
    [18] combo
    [19] 0xAA          marcador de fim

Conversao age -> Y: y = age * NOTE_SPEED  (NOTE_SPEED=4)
"""

import pygame
pygame.init()

import threading
import queue
import argparse
from sys import exit

try:
    import serial
    SERIAL_AVAILABLE = True
except ImportError:
    SERIAL_AVAILABLE = False

# ─── Constantes de tela e layout ─────────────────────────────────────────────

SCREEN_W, SCREEN_H = 800, 600
FPS        = 60
NOTE_SPEED = 4          # pixels por frame (deve bater com o Verilog)
HIT_Y      = 520        # posicao Y da hit zone
NOTE_RADIUS = 22
GLOW_SIZE   = 120
GLOW_CENTER = GLOW_SIZE // 2
TRACK_W     = 80

TRACK_X      = [175, 300, 500, 625]
TRACK_LABELS = ['D', 'F', 'J', 'K']
TRACK_COLORS = [
    (255, 220,   0),  # amarelo
    (  0, 180, 255),  # azul
    (  0, 255, 100),  # verde
    (255,  50,  50),  # vermelho
]

BG_COLOR     = (10,  10,  20)
TRACK_BG     = (20,  20,  40)
LINE_COLOR   = (50,  50,  90)
HIT_LINE_COL = (80,  80, 140)

MAX_MISSES   = 10

# Estados da FPGA (devem ser iguais aos estados da UC em Verilog)
STATE_IDLE      = 0
STATE_COUNTDOWN = 1
STATE_PLAY      = 2
STATE_PAUSE     = 3
STATE_WIN       = 4
STATE_LOSE      = 5

PACKET_SIZE = 20
PKT_HEADER  = 0x55
PKT_FOOTER  = 0xAA
EMPTY_SLOT  = 0xFF


# ─── Thread Serial ────────────────────────────────────────────────────────────

class SerialReader(threading.Thread):
    """Le bytes da UART em background e coloca em buffer thread-safe."""

    def __init__(self, port='/dev/ttyUSB0', baudrate=115200):
        super().__init__(daemon=True)
        self.port      = port
        self.baudrate  = baudrate
        self.buf_lock  = threading.Lock()
        self._buf      = bytearray()
        self._stop     = threading.Event()
        self.connected = False

    def run(self):
        if not SERIAL_AVAILABLE:
            return
        try:
            ser = serial.Serial(self.port, self.baudrate, timeout=0.05)
            self.connected = True
            print(f"[Serial] Conectado em {self.port} @ {self.baudrate} baud")
        except Exception as e:
            print(f"[Serial] Nao foi possivel abrir {self.port}: {e}")
            return
        while not self._stop.is_set():
            try:
                waiting = ser.in_waiting
                if waiting > 0:
                    data = ser.read(waiting)
                    with self.buf_lock:
                        self._buf.extend(data)
            except Exception as e:
                print(f"[Serial] Erro: {e}")
                self.connected = False
                break
        if ser.is_open:
            ser.close()

    def read_buf(self):
        """Retorna e limpa o buffer acumulado (thread-safe)."""
        with self.buf_lock:
            data = bytes(self._buf)
            self._buf.clear()
        return data

    def stop(self):
        self._stop.set()


# ─── Parser de pacote ─────────────────────────────────────────────────────────

def parse_packet(data, offset):
    """
    Tenta interpretar um pacote de 20 bytes a partir de 'offset' em 'data'.
    Retorna um dict com o estado do jogo, ou None se invalido.
    """
    if offset + PACKET_SIZE > len(data):
        return None
    if data[offset] != PKT_HEADER or data[offset + 19] != PKT_FOOTER:
        return None

    state        = data[offset + 1] & 0x0F
    countdown    = data[offset + 2]
    notes        = []
    for t in range(4):
        track_notes = []
        for s in range(3):
            age = data[offset + 3 + t * 3 + s]
            if age != EMPTY_SLOT:
                track_notes.append(age * NOTE_SPEED)
        notes.append(track_notes)
    score  = (data[offset + 15] << 8) | data[offset + 16]
    misses = data[offset + 17]
    combo  = data[offset + 18]

    return {
        'state':     state,
        'countdown': countdown,
        'notes':     notes,   # lista de 4 trilhas, cada trilha = lista de Y positions
        'score':     score,
        'misses':    misses,
        'combo':     combo,
    }


def find_packet(buf):
    """
    Procura o primeiro pacote valido em buf.
    Retorna (packet_dict, bytes_consumed) ou (None, 0).
    """
    for i in range(len(buf) - PACKET_SIZE + 1):
        pkt = parse_packet(buf, i)
        if pkt is not None:
            return pkt, i + PACKET_SIZE
    # Nao encontrou pacote completo; descarta tudo exceto os ultimos 19 bytes
    keep = min(len(buf), PACKET_SIZE - 1)
    return None, max(0, len(buf) - keep)


# ─── Renderer ─────────────────────────────────────────────────────────────────

class Renderer:

    def __init__(self, serial_port='/dev/ttyUSB0', baudrate=115200):
        self.screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
        pygame.display.set_caption('Beat by Bit')
        self.clock      = pygame.time.Clock()
        self._font_cache = {}

        # Estado recebido da FPGA
        self.fpga_state    = STATE_IDLE
        self.fpga_countdown = 3
        self.fpga_notes    = [[], [], [], []]
        self.fpga_score    = 0
        self.fpga_misses   = 0
        self.fpga_combo    = 0

        # Efeitos visuais de acerto (locais, puramente cosmeticos)
        self.effects = []
        self._prev_notes = [[], [], [], []]  # para detectar notas que sumiram (acerto)

        self._serial_buf = bytearray()
        self.serial = SerialReader(port=serial_port, baudrate=baudrate)
        self.serial.start()

        self._build_glow_surfaces()
        self._build_btn_surfaces()

    # ── Pre-renderizacao ──────────────────────────────────────────────────────

    def _build_glow_surfaces(self):
        self.glow_surfs = []
        for color in TRACK_COLORS:
            s = pygame.Surface((GLOW_SIZE, GLOW_SIZE), pygame.SRCALPHA)
            pygame.draw.circle(s, (*color, 35),  (GLOW_CENTER, GLOW_CENTER), 58)
            pygame.draw.circle(s, (*color, 70),  (GLOW_CENTER, GLOW_CENTER), 40)
            pygame.draw.circle(s, (*color, 150), (GLOW_CENTER, GLOW_CENTER), NOTE_RADIUS + 4)
            pygame.draw.circle(s, color,         (GLOW_CENTER, GLOW_CENTER), NOTE_RADIUS)
            pygame.draw.circle(s, (255, 255, 255), (GLOW_CENTER, GLOW_CENTER), NOTE_RADIUS, 2)
            self.glow_surfs.append(s)

    def _build_btn_surfaces(self):
        r    = NOTE_RADIUS + 4
        size = r * 2 + 4
        self.btn_off = []
        self.btn_on  = []
        for color in TRACK_COLORS:
            off = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.circle(off, (*color, 80), (size // 2, size // 2), r, 3)
            self.btn_off.append(off)
            on = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.circle(on, (*color, 200), (size // 2, size // 2), r + 6)
            pygame.draw.circle(on, color,          (size // 2, size // 2), r)
            pygame.draw.circle(on, (255, 255, 255), (size // 2, size // 2), r, 2)
            self.btn_on.append(on)

    # ── Fontes ────────────────────────────────────────────────────────────────

    def font(self, size):
        if size not in self._font_cache:
            self._font_cache[size] = pygame.font.Font('assets/fonts/Pixeltype.ttf', size)
        return self._font_cache[size]

    # ── Leitura UART ──────────────────────────────────────────────────────────

    def _process_serial(self):
        """Drena o buffer serial e atualiza o estado da FPGA."""
        new_data = self.serial.read_buf()
        if new_data:
            self._serial_buf.extend(new_data)

        while len(self._serial_buf) >= PACKET_SIZE:
            pkt, consumed = find_packet(self._serial_buf)
            self._serial_buf = self._serial_buf[consumed:]
            if pkt is None:
                break
            # Guarda notas anteriores para detectar acertos (efeito visual)
            self._prev_notes = [list(t) for t in self.fpga_notes]
            # Atualiza estado
            self.fpga_state     = pkt['state']
            self.fpga_countdown = pkt['countdown']
            self.fpga_notes     = pkt['notes']
            self.fpga_score     = pkt['score']
            self.fpga_misses    = pkt['misses']
            self.fpga_combo     = pkt['combo']
            # Detecta notas que sumiram perto da hit zone => acerto
            self._detect_hits()

    def _detect_hits(self):
        """Cria efeito visual quando uma nota desaparece perto da hit zone."""
        for i in range(4):
            prev_set = set(self._prev_notes[i])
            curr_set = set(self.fpga_notes[i])
            for y in prev_set - curr_set:
                if abs(y - HIT_Y) <= 60:  # nota sumiu perto da hit zone
                    self.effects.append({
                        'x': TRACK_X[i], 'y': HIT_Y,
                        'color': TRACK_COLORS[i],
                        'r': 8, 'alpha': 255, 'active': True,
                    })

    # ── Efeitos ───────────────────────────────────────────────────────────────

    def _update_draw_effects(self):
        for eff in self.effects:
            if not eff['active']:
                continue
            eff['r']     += 5
            eff['alpha']  = max(0, eff['alpha'] - 18)
            if eff['r'] >= 70:
                eff['active'] = False
                continue
            size = eff['r'] * 2
            s = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.circle(s, (*eff['color'], eff['alpha']),
                               (eff['r'], eff['r']), eff['r'], 3)
            self.screen.blit(s, (eff['x'] - eff['r'], eff['y'] - eff['r']))
        self.effects = [e for e in self.effects if e['active']]

    # ── Componentes de desenho ────────────────────────────────────────────────

    def _draw_tracks(self, alpha=255):
        for i, x in enumerate(TRACK_X):
            s = pygame.Surface((TRACK_W, SCREEN_H), pygame.SRCALPHA)
            s.fill((*TRACK_BG, alpha))
            self.screen.blit(s, (x - TRACK_W // 2, 0))
            pygame.draw.line(self.screen, (*LINE_COLOR, alpha),
                             (x - TRACK_W // 2, 0), (x - TRACK_W // 2, SCREEN_H), 1)
            pygame.draw.line(self.screen, (*LINE_COLOR, alpha),
                             (x + TRACK_W // 2, 0), (x + TRACK_W // 2, SCREEN_H), 1)

    def _draw_hit_zone(self, active_tracks=None):
        """Desenha a linha da hit zone e os indicadores de botao.
        active_tracks: set de indices de trilha com botao pressionado agora.
        """
        for offset, a in [(3, 40), (2, 80), (1, 160), (0, 255)]:
            color = (*HIT_LINE_COL, a) if offset else HIT_LINE_COL
            pygame.draw.line(self.screen, color,
                             (0, HIT_Y + offset), (SCREEN_W, HIT_Y + offset), 1)

        r    = NOTE_RADIUS + 4
        size = r * 2 + 4
        for i, x in enumerate(TRACK_X):
            surf = self.btn_on[i] if (active_tracks and i in active_tracks) else self.btn_off[i]
            self.screen.blit(surf, (x - size // 2, HIT_Y - size // 2))
            label = self.font(22).render(TRACK_LABELS[i], True, TRACK_COLORS[i])
            self.screen.blit(label, label.get_rect(center=(x, HIT_Y + r + 12)))

    def _draw_notes(self, notes):
        for i, track in enumerate(notes):
            for y in track:
                if 0 <= y <= SCREEN_H + NOTE_RADIUS:
                    self.screen.blit(
                        self.glow_surfs[i],
                        (TRACK_X[i] - GLOW_CENTER, y - GLOW_CENTER)
                    )

    def _draw_hud(self, score, misses, combo):
        score_txt = self.font(36).render(f"SCORE  {score:06d}", True, (200, 200, 255))
        self.screen.blit(score_txt, (20, 16))

        miss_color = (255, 80, 80) if misses > 5 else (150, 150, 200)
        miss_txt = self.font(28).render(f"ERROS {misses}/{MAX_MISSES}", True, miss_color)
        self.screen.blit(miss_txt, (20, 54))

        if combo >= 3:
            combo_txt = self.font(36).render(f"COMBO x{combo}", True, (255, 220, 0))
            self.screen.blit(combo_txt, combo_txt.get_rect(topright=(SCREEN_W - 20, 16)))

        status_color = (0, 255, 100) if self.serial.connected else (100, 100, 100)
        status_label = "FPGA ON" if self.serial.connected else "FPGA OFF"
        status_txt = self.font(20).render(status_label, True, status_color)
        self.screen.blit(status_txt, status_txt.get_rect(topright=(SCREEN_W - 20, 54)))

    # ── Telas ─────────────────────────────────────────────────────────────────

    def _draw_idle(self):
        self.screen.fill(BG_COLOR)
        title = self.font(110).render('Beat by Bit', True, (220, 40, 40))
        glow_s = pygame.Surface(title.get_size(), pygame.SRCALPHA)
        glow_title = self.font(110).render('Beat by Bit', True, (255, 80, 80))
        glow_s.blit(glow_title, (0, 0))
        glow_s.set_alpha(80)
        rect = title.get_rect(center=(SCREEN_W // 2, 200))
        self.screen.blit(glow_s, (rect.x - 3, rect.y + 3))
        self.screen.blit(title, rect)

        if pygame.time.get_ticks() % 1000 < 650:
            sub = self.font(50).render('Aperte START para jogar', True, (255, 220, 0))
            self.screen.blit(sub, sub.get_rect(center=(SCREEN_W // 2, 360)))

        hint = self.font(30).render('FPGA: botoes 0-3 = trilhas  |  botao 4 = START', True, (80, 80, 120))
        self.screen.blit(hint, hint.get_rect(center=(SCREEN_W // 2, 540)))

    def _draw_countdown(self, sec):
        self.screen.fill(BG_COLOR)
        self._draw_tracks()
        self._draw_hit_zone()

        if sec > 0:
            num = self.font(220).render(str(sec), True, (255, 60, 60))
            self.screen.blit(num, num.get_rect(center=(SCREEN_W // 2, SCREEN_H // 2 - 40)))

    def _draw_play(self, notes, score, misses, combo):
        self.screen.fill(BG_COLOR)
        self._draw_tracks()
        self._draw_notes(notes)
        self._draw_hit_zone()
        self._update_draw_effects()
        self._draw_hud(score, misses, combo)

    def _draw_pause(self):
        self.screen.fill(BG_COLOR)
        self._draw_tracks(alpha=60)
        overlay = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 140))
        self.screen.blit(overlay, (0, 0))
        pause_txt = self.font(90).render('PAUSADO', True, (200, 200, 255))
        self.screen.blit(pause_txt, pause_txt.get_rect(center=(SCREEN_W // 2, 240)))
        cont = self.font(44).render('Aperte START para continuar', True, (150, 150, 200))
        self.screen.blit(cont, cont.get_rect(center=(SCREEN_W // 2, 360)))
        self._draw_hud(self.fpga_score, self.fpga_misses, self.fpga_combo)

    def _draw_endscreen(self, win, score, misses):
        overlay = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        overlay.fill((0, 40, 0, 180) if win else (40, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        color   = (0, 255, 100) if win else (255, 60, 60)
        message = 'VITORIA!' if win else 'GAME OVER'
        msg_txt = self.font(100).render(message, True, color)
        self.screen.blit(msg_txt, msg_txt.get_rect(center=(SCREEN_W // 2, 200)))

        score_txt = self.font(60).render(f"Score: {score:06d}", True, (255, 255, 180))
        self.screen.blit(score_txt, score_txt.get_rect(center=(SCREEN_W // 2, 320)))

        miss_txt = self.font(40).render(f"Erros: {misses}", True, (200, 180, 180))
        self.screen.blit(miss_txt, miss_txt.get_rect(center=(SCREEN_W // 2, 390)))

        if pygame.time.get_ticks() % 1000 < 650:
            restart = self.font(44).render('Aperte START para jogar novamente', True, (200, 200, 200))
            self.screen.blit(restart, restart.get_rect(center=(SCREEN_W // 2, 490)))

    # ── Loop principal ────────────────────────────────────────────────────────

    def run(self):
        while True:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.serial.stop()
                    pygame.quit()
                    exit()

            # Atualiza estado a partir dos pacotes UART recebidos da FPGA
            self._process_serial()

            # Renderiza conforme estado atual da FPGA
            s = self.fpga_state
            if s == STATE_IDLE:
                self._draw_idle()
            elif s == STATE_COUNTDOWN:
                self._draw_countdown(self.fpga_countdown)
            elif s == STATE_PLAY:
                self._draw_play(self.fpga_notes, self.fpga_score,
                                self.fpga_misses, self.fpga_combo)
            elif s == STATE_PAUSE:
                self._draw_pause()
            elif s == STATE_WIN:
                self.screen.fill(BG_COLOR)
                self._draw_endscreen(win=True,
                                     score=self.fpga_score, misses=self.fpga_misses)
            elif s == STATE_LOSE:
                self.screen.fill(BG_COLOR)
                self._draw_endscreen(win=False,
                                     score=self.fpga_score, misses=self.fpga_misses)

            pygame.display.flip()
            self.clock.tick(FPS)


# ─── Entrada ──────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Beat by Bit - Renderer')
    parser.add_argument('--port', default='/dev/ttyUSB0',
                        help='Porta serial da FPGA (padrao: /dev/ttyUSB0)')
    parser.add_argument('--baud', type=int, default=115200,
                        help='Baudrate UART (padrao: 115200)')
    args = parser.parse_args()

    Renderer(serial_port=args.port, baudrate=args.baud).run()
