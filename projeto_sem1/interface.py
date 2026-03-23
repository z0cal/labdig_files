import pygame
pygame.init()

import random
import threading
import queue
import argparse
from sys import exit

try:
    import serial
    SERIAL_AVAILABLE = True
except ImportError:
    SERIAL_AVAILABLE = False

# ─── Constantes ──────────────────────────────────────────────────────────────

SCREEN_W, SCREEN_H = 800, 600
FPS = 60

TRACK_X      = [175, 300, 500, 625]
HIT_Y        = 520
NOTE_RADIUS  = 22
MISS_THRESHOLD = 45

BG_COLOR     = (10, 10, 20)
TRACK_BG     = (20, 20, 40)
LINE_COLOR   = (50, 50, 90)
HIT_LINE_COL = (80, 80, 140)

TRACK_COLORS = [
    (255, 220,  0),   # amarelo
    (0,   180, 255),  # azul
    (0,   255, 100),  # verde
    (255,  50,  50),  # vermelho
]

TRACK_KEYS = [pygame.K_d, pygame.K_f, pygame.K_j, pygame.K_k]
TRACK_LABELS = ['D', 'F', 'J', 'K']

NOTE_SPEED    = 4
SPAWN_PROB    = 0.025
MAX_MISSES    = 10
GAME_DURATION = 60_000   # ms até vitória

SCORE_HIT   = 100
SCORE_MISS  = -50

GLOW_SIZE   = 120        # tamanho da surface de glow pré-renderizada
GLOW_CENTER = GLOW_SIZE // 2


# ─── Thread Serial ────────────────────────────────────────────────────────────

class SerialReader(threading.Thread):
    """Lê bytes da UART em background e coloca em uma queue thread-safe."""

    def __init__(self, port='/dev/ttyUSB0', baudrate=9600):
        super().__init__(daemon=True)
        self.port = port
        self.baudrate = baudrate
        self.data_queue = queue.Queue()
        self._stop_event = threading.Event()
        self.connected = False

    def run(self):
        if not SERIAL_AVAILABLE:
            return
        try:
            ser = serial.Serial(self.port, self.baudrate, timeout=0.05)
            self.connected = True
            print(f"[Serial] Conectado em {self.port} @ {self.baudrate} baud")
        except Exception as e:
            print(f"[Serial] Não foi possível abrir {self.port}: {e}")
            return

        while not self._stop_event.is_set():
            try:
                if ser.in_waiting > 0:
                    raw = ser.read(1)
                    if raw:
                        self.data_queue.put(raw[0])
            except Exception as e:
                print(f"[Serial] Erro: {e}")
                self.connected = False
                break

        if ser.is_open:
            ser.close()

    def stop(self):
        self._stop_event.set()


# ─── Jogo ─────────────────────────────────────────────────────────────────────

class Game:

    def __init__(self, serial_port='/dev/ttyUSB0'):
        self.screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
        pygame.display.set_caption('Beat by Bit')
        self.clock = pygame.time.Clock()
        self._font_cache = {}

        self.state = 'IDLE'
        self.notes = []
        self.effects = []
        self.score = 0
        self.misses = 0
        self.combo = 0
        self.button_press_time = [0] * 4
        self.countdown_start = 0
        self.game_start = 0
        self.paused_snapshot = None

        self._prev_serial_byte = 0
        self.serial = SerialReader(port=serial_port)
        self.serial.start()

        self._build_glow_surfaces()
        self._build_hit_indicator_surfaces()

    # ── Pré-renderização ──────────────────────────────────────────────────────

    def _build_glow_surfaces(self):
        """Cria uma surface de glow por cor de trilha."""
        self.glow_surfs = []
        for color in TRACK_COLORS:
            s = pygame.Surface((GLOW_SIZE, GLOW_SIZE), pygame.SRCALPHA)
            pygame.draw.circle(s, (*color, 35),  (GLOW_CENTER, GLOW_CENTER), 58)
            pygame.draw.circle(s, (*color, 70),  (GLOW_CENTER, GLOW_CENTER), 40)
            pygame.draw.circle(s, (*color, 150), (GLOW_CENTER, GLOW_CENTER), NOTE_RADIUS + 4)
            pygame.draw.circle(s, color,         (GLOW_CENTER, GLOW_CENTER), NOTE_RADIUS)
            pygame.draw.circle(s, (255, 255, 255), (GLOW_CENTER, GLOW_CENTER), NOTE_RADIUS, 2)
            self.glow_surfs.append(s)

    def _build_hit_indicator_surfaces(self):
        """Cria surfaces dos indicadores de botão (apagado e aceso)."""
        r = NOTE_RADIUS + 4
        size = r * 2 + 4
        self.btn_off = []
        self.btn_on  = []
        for color in TRACK_COLORS:
            # apagado: apenas contorno
            off = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.circle(off, (*color, 80), (size//2, size//2), r, 3)
            self.btn_off.append(off)
            # aceso: preenchido + brilho
            on = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.circle(on, (*color, 200), (size//2, size//2), r + 6)
            pygame.draw.circle(on, color,          (size//2, size//2), r)
            pygame.draw.circle(on, (255,255,255),  (size//2, size//2), r, 2)
            self.btn_on.append(on)

    # ── Fontes ────────────────────────────────────────────────────────────────

    def font(self, size):
        """Retorna fonte pixel com cache."""
        if size not in self._font_cache:
            self._font_cache[size] = pygame.font.Font('assets/fonts/Pixeltype.ttf', size)
        return self._font_cache[size]

    # ── Lógica de estados ─────────────────────────────────────────────────────

    def _handle_start(self):
        if self.state == 'IDLE':
            self.state = 'COUNTDOWN'
            self.countdown_start = pygame.time.get_ticks()
        elif self.state == 'PLAY':
            self.paused_snapshot = self.screen.copy()
            self.state = 'PAUSE'
        elif self.state == 'PAUSE':
            self.state = 'PLAY'
        elif self.state in ('WIN', 'LOSE'):
            self._reset()

    def _reset(self):
        self.state = 'IDLE'
        self.notes.clear()
        self.effects.clear()
        self.score = 0
        self.misses = 0
        self.combo = 0
        self.button_press_time = [0] * 4
        self._prev_serial_byte = 0

    def process_button(self, idx):
        """Checa acerto de uma nota; chamado tanto por teclado quanto por serial."""
        self.button_press_time[idx] = pygame.time.get_ticks()
        hit = None
        best_dist = MISS_THRESHOLD + 1
        for note in self.notes:
            if note['btn'] == idx:
                dist = abs(note['y'] - HIT_Y)
                if dist < best_dist:
                    best_dist = dist
                    hit = note
        if hit:
            self.notes.remove(hit)
            self.score += SCORE_HIT
            self.combo += 1
            self._spawn_effect(idx)
        else:
            self.score = max(0, self.score + SCORE_MISS)
            self.combo = 0

    # ── Serial ────────────────────────────────────────────────────────────────

    @staticmethod
    def _rising_edges(prev, curr):
        return (~prev) & curr & 0x1F

    def _process_serial(self):
        try:
            while True:
                byte_val = self.serial.data_queue.get_nowait()
                edges = self._rising_edges(self._prev_serial_byte, byte_val)
                self._prev_serial_byte = byte_val
                if edges & 0x10:
                    self._handle_start()
                if self.state == 'PLAY':
                    for i in range(4):
                        if edges & (1 << i):
                            self.process_button(i)
        except queue.Empty:
            pass

    # ── Notas ─────────────────────────────────────────────────────────────────

    def _spawn_note(self):
        idx = random.randint(0, 3)
        self.notes.append({'btn': idx, 'x': TRACK_X[idx], 'y': -NOTE_RADIUS})

    def _update_notes(self):
        for note in self.notes:
            note['y'] += NOTE_SPEED
        missed = [n for n in self.notes if n['y'] > SCREEN_H + NOTE_RADIUS]
        for note in missed:
            self.notes.remove(note)
            self.misses += 1
            self.score = max(0, self.score + SCORE_MISS)
            self.combo = 0
        if self.misses >= MAX_MISSES:
            self.state = 'LOSE'
        elapsed = pygame.time.get_ticks() - self.game_start
        if elapsed >= GAME_DURATION:
            self.state = 'WIN'

    # ── Efeitos visuais ───────────────────────────────────────────────────────

    def _spawn_effect(self, idx):
        self.effects.append({
            'x': TRACK_X[idx], 'y': HIT_Y,
            'color': TRACK_COLORS[idx],
            'r': 8, 'alpha': 255, 'active': True,
        })

    def _update_draw_effects(self):
        for eff in self.effects:
            if not eff['active']:
                continue
            eff['r'] += 5
            eff['alpha'] = max(0, eff['alpha'] - 18)
            if eff['r'] >= 70:
                eff['active'] = False
                continue
            size = eff['r'] * 2
            s = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.circle(s, (*eff['color'], eff['alpha']),
                               (eff['r'], eff['r']), eff['r'], 3)
            self.screen.blit(s, (eff['x'] - eff['r'], eff['y'] - eff['r']))
        self.effects = [e for e in self.effects if e['active']]

    # ── Desenho de componentes reutilizáveis ──────────────────────────────────

    def _draw_tracks(self, alpha=255):
        track_w = 80
        for i, x in enumerate(TRACK_X):
            rect = pygame.Rect(x - track_w // 2, 0, track_w, SCREEN_H)
            s = pygame.Surface((track_w, SCREEN_H), pygame.SRCALPHA)
            s.fill((*TRACK_BG, alpha))
            self.screen.blit(s, rect.topleft)
            pygame.draw.line(self.screen, (*LINE_COLOR, alpha),
                             (x - track_w // 2, 0), (x - track_w // 2, SCREEN_H), 1)
            pygame.draw.line(self.screen, (*LINE_COLOR, alpha),
                             (x + track_w // 2, 0), (x + track_w // 2, SCREEN_H), 1)

    def _draw_hit_zone(self):
        # Linha brilhante
        for offset, a in [(3, 40), (2, 80), (1, 160), (0, 255)]:
            pygame.draw.line(self.screen,
                             (*HIT_LINE_COL, a) if offset else HIT_LINE_COL,
                             (0, HIT_Y + offset), (SCREEN_W, HIT_Y + offset), 1)

        # Indicadores de botão
        now = pygame.time.get_ticks()
        r = NOTE_RADIUS + 4
        size = r * 2 + 4
        for i, x in enumerate(TRACK_X):
            pressed = (now - self.button_press_time[i]) < 100
            surf = self.btn_on[i] if pressed else self.btn_off[i]
            self.screen.blit(surf, (x - size // 2, HIT_Y - size // 2))
            label = self.font(22).render(TRACK_LABELS[i], True, TRACK_COLORS[i])
            self.screen.blit(label, label.get_rect(center=(x, HIT_Y + r + 12)))

    def _draw_notes(self):
        for note in self.notes:
            i = note['btn']
            s = self.glow_surfs[i]
            self.screen.blit(s, (note['x'] - GLOW_CENTER, note['y'] - GLOW_CENTER))

    def _draw_hud(self):
        # Score
        score_txt = self.font(36).render(f"SCORE  {self.score:06d}", True, (200, 200, 255))
        self.screen.blit(score_txt, (20, 16))
        # Misses
        miss_txt = self.font(28).render(f"ERROS {self.misses}/{MAX_MISSES}", True,
                                        (255, 80, 80) if self.misses > 5 else (150, 150, 200))
        self.screen.blit(miss_txt, (20, 54))
        # Combo
        if self.combo >= 3:
            combo_txt = self.font(36).render(f"COMBO x{self.combo}", True, (255, 220, 0))
            self.screen.blit(combo_txt, combo_txt.get_rect(topright=(SCREEN_W - 20, 16)))
        # Indicador serial
        status_color = (0, 255, 100) if self.serial.connected else (100, 100, 100)
        status_label = "SERIAL ON" if self.serial.connected else "SERIAL OFF"
        status_txt = self.font(20).render(status_label, True, status_color)
        self.screen.blit(status_txt, status_txt.get_rect(topright=(SCREEN_W - 20, 54)))

    # ── Telas ─────────────────────────────────────────────────────────────────

    def _draw_idle(self):
        self.screen.fill(BG_COLOR)

        # Título neon
        title = self.font(110).render('Beat by Bit', True, (220, 40, 40))
        glow_title = self.font(110).render('Beat by Bit', True, (255, 80, 80))
        rect = title.get_rect(center=(SCREEN_W // 2, 200))
        glow_s = pygame.Surface(title.get_size(), pygame.SRCALPHA)
        glow_s.blit(glow_title, (0, 0))
        glow_s.set_alpha(80)
        self.screen.blit(glow_s, (rect.x - 3, rect.y + 3))
        self.screen.blit(title, rect)

        # Subtítulo piscando
        if pygame.time.get_ticks() % 1000 < 650:
            sub = self.font(50).render('Aperte START para jogar', True, (255, 220, 0))
            self.screen.blit(sub, sub.get_rect(center=(SCREEN_W // 2, 360)))

        # Teclas de referência
        hint = self.font(30).render('Teclado:  D   F   J   K   |   SPACE = START', True, (80, 80, 120))
        self.screen.blit(hint, hint.get_rect(center=(SCREEN_W // 2, 540)))

    def _draw_countdown(self):
        self.screen.fill(BG_COLOR)
        self._draw_tracks()
        self._draw_hit_zone()

        elapsed = pygame.time.get_ticks() - self.countdown_start
        remaining = 3 - (elapsed // 1000)
        if remaining <= 0:
            self.state = 'PLAY'
            self.game_start = pygame.time.get_ticks()
            return

        pulse = (elapsed % 1000) / 1000.0
        size = int(220 - 100 * pulse)
        num = self.font(max(size, 60)).render(str(remaining), True, (255, 60, 60))
        alpha_s = pygame.Surface(num.get_size(), pygame.SRCALPHA)
        alpha_s.blit(num, (0, 0))
        alpha_s.set_alpha(int(255 - 180 * pulse))
        self.screen.blit(alpha_s, alpha_s.get_rect(center=(SCREEN_W // 2, SCREEN_H // 2 - 40)))

    def _draw_play(self):
        self.screen.fill(BG_COLOR)
        self._draw_tracks()
        self._draw_notes()
        self._draw_hit_zone()
        self._update_draw_effects()
        self._draw_hud()

    def _draw_pause(self):
        if self.paused_snapshot:
            self.screen.blit(self.paused_snapshot, (0, 0))
        overlay = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 160))
        self.screen.blit(overlay, (0, 0))

        pause_txt = self.font(90).render('PAUSADO', True, (200, 200, 255))
        self.screen.blit(pause_txt, pause_txt.get_rect(center=(SCREEN_W // 2, 240)))
        cont = self.font(44).render('Aperte START para continuar', True, (150, 150, 200))
        self.screen.blit(cont, cont.get_rect(center=(SCREEN_W // 2, 360)))

    def _draw_endscreen(self, win):
        overlay = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        overlay.fill((0, 40, 0, 180) if win else (40, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        color   = (0, 255, 100) if win else (255, 60, 60)
        message = 'VITÓRIA!' if win else 'GAME OVER'
        msg_txt = self.font(100).render(message, True, color)
        self.screen.blit(msg_txt, msg_txt.get_rect(center=(SCREEN_W // 2, 200)))

        score_txt = self.font(60).render(f"Score: {self.score:06d}", True, (255, 255, 180))
        self.screen.blit(score_txt, score_txt.get_rect(center=(SCREEN_W // 2, 320)))

        miss_txt = self.font(40).render(f"Erros: {self.misses}", True, (200, 180, 180))
        self.screen.blit(miss_txt, miss_txt.get_rect(center=(SCREEN_W // 2, 390)))

        if pygame.time.get_ticks() % 1000 < 650:
            restart = self.font(44).render('Aperte START para jogar novamente', True, (200, 200, 200))
            self.screen.blit(restart, restart.get_rect(center=(SCREEN_W // 2, 490)))

    # ── Loop principal ────────────────────────────────────────────────────────

    def run(self):
        while True:
            # Eventos pygame
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.serial.stop()
                    pygame.quit()
                    exit()
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_SPACE:
                        self._handle_start()
                    if self.state == 'PLAY':
                        for i, key in enumerate(TRACK_KEYS):
                            if event.key == key:
                                self.process_button(i)

            # Serial
            self._process_serial()

            # Lógica de jogo
            if self.state == 'PLAY':
                self._update_notes()
                if random.random() < SPAWN_PROB:
                    self._spawn_note()

            # Desenho
            if self.state == 'IDLE':
                self._draw_idle()
            elif self.state == 'COUNTDOWN':
                self._draw_countdown()
            elif self.state == 'PLAY':
                self._draw_play()
            elif self.state == 'PAUSE':
                self._draw_pause()
            elif self.state == 'WIN':
                self._draw_endscreen(win=True)
            elif self.state == 'LOSE':
                self._draw_endscreen(win=False)

            pygame.display.flip()
            self.clock.tick(FPS)


# ─── Entrada ──────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Beat by Bit')
    parser.add_argument('--port', default='/dev/ttyUSB0',
                        help='Porta serial da FPGA (padrão: /dev/ttyUSB0)')
    parser.add_argument('--baud', type=int, default=9600,
                        help='Baudrate UART (padrão: 9600)')
    args = parser.parse_args()

    Game(serial_port=args.port).run()
