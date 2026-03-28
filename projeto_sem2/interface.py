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
import math
import random
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

        # Efeitos visuais tipados
        self._hit_effects  = []   # burst de acerto
        self._miss_effects = []   # flash vermelho de erro
        self._prev_notes   = [[], [], [], []]

        # Surface scratch reutilizavel (evita alocacao por frame)
        self.scratch = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)

        self._serial_buf = bytearray()
        self.serial = SerialReader(port=serial_port, baudrate=baudrate)
        self.serial.start()

        self._build_glow_surfaces()
        self._build_btn_surfaces()
        self._build_scanline_surf()
        self._build_bg_grid_surf()
        self._build_miss_surfs()
        self._build_score_backdrop()
        self._build_ghost_note_surfs()
        self._init_idle_anim()

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

    def _build_scanline_surf(self):
        """Pre-renderiza overlay de scanlines CRT (linhas escuras a cada 2px)."""
        self.scanline_surf = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        for row in range(0, SCREEN_H, 2):
            pygame.draw.rect(self.scanline_surf, (0, 0, 0, 60), (0, row, SCREEN_W, 1))

    def _build_bg_grid_surf(self):
        """Pre-renderiza grid horizontal sutil no fundo."""
        self.bg_grid_surf = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        for y in range(0, SCREEN_H, 40):
            pygame.draw.line(self.bg_grid_surf, (30, 30, 65, 255),
                             (0, y), (SCREEN_W, y), 1)

    def _build_miss_surfs(self):
        """Pre-renderiza superficies vermelhas para flash de erro por trilha."""
        # Superficie sem SRCALPHA para set_alpha() funcionar corretamente
        self.miss_lane_surfs = []
        for _ in range(4):
            s = pygame.Surface((TRACK_W, SCREEN_H))
            s.fill((255, 30, 30))
            self.miss_lane_surfs.append(s)

    def _build_score_backdrop(self):
        """Pre-renderiza painel escuro atras do HUD de score."""
        self.score_backdrop = pygame.Surface((260, 76), pygame.SRCALPHA)
        pygame.draw.rect(self.score_backdrop, (0, 0, 0, 150),
                         (0, 0, 260, 76), border_radius=6)
        pygame.draw.rect(self.score_backdrop, (60, 60, 120, 180),
                         (0, 0, 260, 76), 1, border_radius=6)

    def _build_ghost_note_surfs(self):
        """Versao fantasma das notas para a animacao da tela idle."""
        self.ghost_note_surfs = []
        for color in TRACK_COLORS:
            s = pygame.Surface((GLOW_SIZE, GLOW_SIZE), pygame.SRCALPHA)
            pygame.draw.circle(s, (*color, 12),  (GLOW_CENTER, GLOW_CENTER), 58)
            pygame.draw.circle(s, (*color, 25),  (GLOW_CENTER, GLOW_CENTER), 40)
            pygame.draw.circle(s, (*color, 55),  (GLOW_CENTER, GLOW_CENTER), NOTE_RADIUS + 4)
            pygame.draw.circle(s, (*color, 90),  (GLOW_CENTER, GLOW_CENTER), NOTE_RADIUS)
            pygame.draw.circle(s, (200, 200, 255, 50), (GLOW_CENTER, GLOW_CENTER), NOTE_RADIUS, 2)
            self.ghost_note_surfs.append(s)

    def _init_idle_anim(self):
        """Inicializa estado da animacao de fundo da tela idle."""
        self._idle_notes = []
        for lane in range(4):
            for _ in range(4):
                self._idle_notes.append({
                    'lane': lane,
                    'y': float(random.randint(-SCREEN_H, SCREEN_H)),
                    'speed': random.uniform(0.8, 2.0),
                })

        self._idle_stars = []
        for _ in range(90):
            self._idle_stars.append({
                'x': float(random.randint(0, SCREEN_W)),
                'y': float(random.randint(0, SCREEN_H)),
                'vy': random.uniform(0.15, 0.55),
                'size': random.choice([1, 1, 1, 2, 2, 3]),
                'base_alpha': random.randint(40, 160),
                'phase': random.uniform(0, math.pi * 2),
            })

    def _draw_idle_anim(self):
        """Atualiza e desenha a animacao de fundo da tela idle."""
        ticks = pygame.time.get_ticks() * 0.001

        # Estrelas flutuando para cima com twinkle
        for star in self._idle_stars:
            star['y'] -= star['vy']
            if star['y'] < -4:
                star['y'] = float(SCREEN_H + 4)
                star['x'] = float(random.randint(0, SCREEN_W))
            alpha = int(star['base_alpha'] * (0.5 + 0.5 * math.sin(ticks * 2.1 + star['phase'])))
            color = (alpha, alpha, min(255, alpha + 60))
            pygame.draw.circle(self.screen, color,
                               (int(star['x']), int(star['y'])), star['size'])

        # Notas fantasma caindo nas trilhas
        for note in self._idle_notes:
            note['y'] += note['speed']
            if note['y'] > SCREEN_H + GLOW_CENTER:
                note['y'] = float(random.randint(-200, -GLOW_CENTER))
                note['speed'] = random.uniform(0.8, 2.0)
            y = int(note['y'])
            lane = note['lane']
            self.screen.blit(
                self.ghost_note_surfs[lane],
                (TRACK_X[lane] - GLOW_CENTER, y - GLOW_CENTER),
            )

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
            self._prev_notes = [list(t) for t in self.fpga_notes]
            self.fpga_state     = pkt['state']
            self.fpga_countdown = pkt['countdown']
            self.fpga_notes     = pkt['notes']
            self.fpga_score     = pkt['score']
            self.fpga_misses    = pkt['misses']
            self.fpga_combo     = pkt['combo']
            self._detect_note_events()

    def _detect_note_events(self):
        """Detecta notas que sumiram e cria efeito de acerto ou erro."""
        for i in range(4):
            prev_set = set(self._prev_notes[i])
            curr_set = set(self.fpga_notes[i])
            for y in prev_set - curr_set:
                if abs(y - HIT_Y) <= 60:
                    # Nota sumiu perto da hit zone → acerto
                    self._spawn_hit_effect(i, TRACK_X[i], HIT_Y)
                elif y > HIT_Y + 60:
                    # Nota sumiu abaixo da hit zone → erro
                    self._spawn_miss_effect(i)

    # ── Spawn de efeitos ──────────────────────────────────────────────────────

    def _spawn_hit_effect(self, lane, x, y):
        """Cria burst de acerto: 3 aneis expansivos + 7 particulas + flash."""
        particles = []
        for i in range(7):
            angle = 2 * math.pi * i / 7 + random.uniform(-0.3, 0.3)
            speed = random.uniform(2.5, 5.5)
            size  = random.choice([3, 4, 4, 5])
            particles.append({
                'px': float(x), 'py': float(y),
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'alpha': 255, 'size': size,
            })
        self._hit_effects.append({
            'lane': lane, 'x': x, 'y': y,
            'color': TRACK_COLORS[lane],
            'age': 0,
            'rings': [
                {'r': 8,  'alpha': 255, 'delay': 0},
                {'r': 5,  'alpha': 220, 'delay': 5},
                {'r': 3,  'alpha': 180, 'delay': 10},
            ],
            'particles': particles,
            'flash_alpha': 255,
            'active': True,
        })

    def _spawn_miss_effect(self, lane):
        """Cria flash vermelho de erro na trilha + vinheta nas bordas."""
        self._miss_effects.append({
            'lane': lane, 'x': TRACK_X[lane],
            'age': 0, 'lane_alpha': 200, 'vignette_alpha': 140,
            'active': True,
        })

    # ── Atualizacao de efeitos ────────────────────────────────────────────────

    def _advance_effects(self):
        """Avanca o estado de todos os efeitos. Chamado uma vez por frame."""
        for eff in self._hit_effects:
            if not eff['active']:
                continue
            eff['age'] += 1
            eff['flash_alpha'] = max(0, eff['flash_alpha'] - 30)
            for ring in eff['rings']:
                if eff['age'] >= ring['delay']:
                    ring['r']     += 6
                    ring['alpha']  = max(0, ring['alpha'] - 12)
            for p in eff['particles']:
                p['px'] += p['vx']
                p['py'] += p['vy']
                p['vy'] += 0.15   # gravidade
                p['alpha'] = max(0, p['alpha'] - 10)
            if eff['age'] >= 45:
                eff['active'] = False

        for eff in self._miss_effects:
            if not eff['active']:
                continue
            eff['age'] += 1
            eff['lane_alpha']     = max(0, eff['lane_alpha'] - 10)
            eff['vignette_alpha'] = max(0, eff['vignette_alpha'] - 7)
            if eff['age'] >= 25:
                eff['active'] = False

        self._hit_effects  = [e for e in self._hit_effects  if e['active']]
        self._miss_effects = [e for e in self._miss_effects if e['active']]

    # ── Componentes de desenho ────────────────────────────────────────────────

    def _draw_bg_grid(self):
        self.screen.blit(self.bg_grid_surf, (0, 0))

    def _draw_tracks(self, alpha=255):
        for i, x in enumerate(TRACK_X):
            s = pygame.Surface((TRACK_W, SCREEN_H), pygame.SRCALPHA)
            s.fill((*TRACK_BG, alpha))
            self.screen.blit(s, (x - TRACK_W // 2, 0))
            pygame.draw.line(self.screen, (*LINE_COLOR, alpha),
                             (x - TRACK_W // 2, 0), (x - TRACK_W // 2, SCREEN_H), 1)
            pygame.draw.line(self.screen, (*LINE_COLOR, alpha),
                             (x + TRACK_W // 2, 0), (x + TRACK_W // 2, SCREEN_H), 1)

    def _draw_miss_lane_flashes(self):
        """Desenha flash vermelho nas trilhas com erros ativos."""
        for eff in self._miss_effects:
            if not eff['active'] or eff['lane_alpha'] <= 0:
                continue
            surf = self.miss_lane_surfs[eff['lane']]
            surf.set_alpha(eff['lane_alpha'])
            self.screen.blit(surf, (eff['x'] - TRACK_W // 2, 0))

    def _draw_hit_zone(self, active_tracks=None):
        """Desenha a linha da hit zone (pulsante) e os indicadores de botao."""
        ticks = pygame.time.get_ticks()
        pulse = 0.5 + 0.5 * math.sin(ticks * 0.003)
        b = int(80 + 80 * pulse)
        hit_col = (b // 2, b // 2, b)

        for offset, a in [(3, 40), (2, 80), (1, 160), (0, 255)]:
            color = (*hit_col, a) if offset else hit_col
            pygame.draw.line(self.screen, color,
                             (0, HIT_Y + offset), (SCREEN_W, HIT_Y + offset), 1)

        r    = NOTE_RADIUS + 4
        size = r * 2 + 4
        for i, x in enumerate(TRACK_X):
            surf = self.btn_on[i] if (active_tracks and i in active_tracks) else self.btn_off[i]
            self.screen.blit(surf, (x - size // 2, HIT_Y - size // 2))

    def _draw_notes(self, notes):
        for i, track in enumerate(notes):
            for y in track:
                if 0 <= y <= SCREEN_H + NOTE_RADIUS:
                    self.screen.blit(
                        self.glow_surfs[i],
                        (TRACK_X[i] - GLOW_CENTER, y - GLOW_CENTER)
                    )

    def _draw_hit_effects(self):
        """Desenha burst de acerto: flash central, aneis e particulas."""
        self.scratch.fill((0, 0, 0, 0))
        drawn = False

        for eff in self._hit_effects:
            if not eff['active']:
                continue
            color = eff['color']
            x, y  = eff['x'], eff['y']

            # Flash central
            if eff['flash_alpha'] > 0:
                pygame.draw.circle(self.scratch, (*color, eff['flash_alpha']),
                                   (x, y), 28)
                pygame.draw.circle(self.scratch, (255, 255, 255, eff['flash_alpha'] // 2),
                                   (x, y), 14)
                drawn = True

            # Aneis expansivos
            for ring in eff['rings']:
                if eff['age'] >= ring['delay'] and ring['alpha'] > 0:
                    pygame.draw.circle(self.scratch, (*color, ring['alpha']),
                                       (x, y), ring['r'], 3)
                    drawn = True

            # Particulas
            for p in eff['particles']:
                if p['alpha'] > 0:
                    px, py = int(p['px']), int(p['py'])
                    pygame.draw.circle(self.scratch, (*color, p['alpha']),
                                       (px, py), p['size'])
                    drawn = True

        if drawn:
            self.screen.blit(self.scratch, (0, 0))

    def _draw_miss_vignettes(self):
        """Desenha vinheta vermelha nas bordas para erros ativos."""
        for eff in self._miss_effects:
            if not eff['active'] or eff['vignette_alpha'] <= 0:
                continue
            a = eff['vignette_alpha']
            self.scratch.fill((0, 0, 0, 0))
            c = (200, 0, 0, a)
            pygame.draw.rect(self.scratch, c, (0, 0, 60, SCREEN_H))
            pygame.draw.rect(self.scratch, c, (SCREEN_W - 60, 0, 60, SCREEN_H))
            pygame.draw.rect(self.scratch, c, (0, 0, SCREEN_W, 40))
            pygame.draw.rect(self.scratch, c, (0, SCREEN_H - 60, SCREEN_W, 60))
            self.screen.blit(self.scratch, (0, 0))

    def _draw_hud(self, score, misses, combo):
        self.screen.blit(self.score_backdrop, (8, 8))

        score_txt = self.font(36).render(f"SCORE  {score:06d}", True, (200, 200, 255))
        self.screen.blit(score_txt, (20, 16))

        miss_color = (255, 80, 80) if misses > 5 else (150, 150, 200)
        miss_txt = self.font(28).render(f"ERROS {misses}/{MAX_MISSES}", True, miss_color)
        self.screen.blit(miss_txt, (20, 52))

        if combo >= 3:
            ticks = pygame.time.get_ticks()
            if combo >= 20:
                size   = 52
                color  = (255, 255, 200)
                shadow = (180, 120, 0)
                wobble = int(3 * math.sin(ticks * 0.015))
            elif combo >= 10:
                size   = 44
                color  = (255, 160, 0)
                shadow = None
                wobble = int(2 * math.sin(ticks * 0.01))
            else:
                size   = 36
                color  = (255, 220, 0)
                shadow = None
                wobble = 0

            combo_txt = self.font(size).render(f"COMBO x{combo}", True, color)
            base_rect = combo_txt.get_rect(topright=(SCREEN_W - 20 + wobble, 16))
            if shadow:
                shadow_surf = self.font(size).render(f"COMBO x{combo}", True, shadow)
                self.screen.blit(shadow_surf, (base_rect.x + 2, base_rect.y + 2))
            self.screen.blit(combo_txt, base_rect)

        status_color = (0, 255, 100) if self.serial.connected else (100, 100, 100)
        status_label = "FPGA ON" if self.serial.connected else "FPGA OFF"
        status_txt = self.font(20).render(status_label, True, status_color)
        self.screen.blit(status_txt, status_txt.get_rect(topright=(SCREEN_W - 20, 54)))

    # ── Telas ─────────────────────────────────────────────────────────────────

    def _draw_idle(self):
        self.screen.fill(BG_COLOR)
        self._draw_bg_grid()
        self._draw_tracks(alpha=18)
        self._draw_idle_anim()
        self.screen.blit(self.scanline_surf, (0, 0))

        # Titulo com glow pulsante
        ticks = pygame.time.get_ticks()
        pulse = 0.5 + 0.5 * math.sin(ticks * 0.002)
        glow_alpha = int(60 + 80 * pulse)
        title = self.font(110).render('Beat by Bit', True, (220, 40, 40))
        glow_s = pygame.Surface(title.get_size(), pygame.SRCALPHA)
        glow_title = self.font(110).render('Beat by Bit', True, (255, 80, 80))
        glow_s.blit(glow_title, (0, 0))
        glow_s.set_alpha(glow_alpha)
        rect = title.get_rect(center=(SCREEN_W // 2, 200))
        self.screen.blit(glow_s, (rect.x - 4, rect.y + 4))
        self.screen.blit(title, rect)

        if ticks % 1000 < 650:
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
        self._draw_bg_grid()              # 1. grid horizontal sutil
        self._draw_tracks()               # 2. trilhas + bordas verticais
        self._draw_miss_lane_flashes()    # 3. flash vermelho de erro (sob as notas)
        self._draw_notes(notes)           # 4. notas com glow
        self._draw_hit_zone()             # 5. linha pulsante + botoes (sem letras)
        self._advance_effects()           # 6. avanca estado dos efeitos
        self._draw_hit_effects()          # 7. burst: aneis + particulas + flash
        self._draw_hud(score, misses, combo)  # 8. painel HUD
        self._draw_miss_vignettes()       # 9. vinheta vermelha nas bordas
        self.screen.blit(self.scanline_surf, (0, 0))  # 10. scanlines CRT

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

            self._process_serial()

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
