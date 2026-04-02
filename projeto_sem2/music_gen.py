"""
music_gen.py — Gerador de musica chiptune para Beat by Bit.
Gera um loop de 4 compassos em Do menor pentatonico a 140 BPM
e salva em assets/music/bg_music.wav.

Requer: numpy
"""

import os
import wave
import struct

SAMPLE_RATE = 44100
BPM         = 140
AMPLITUDE   = 0.28   # 0.0 - 1.0 (volume geral)

# ── Durações base ─────────────────────────────────────────────────────────────
_BEAT    = int(SAMPLE_RATE * 60 / BPM)       # amostras por beat
_SIXTEEN = _BEAT // 4                         # 1/16 de compasso

# ── Frequências (Do menor pentatônico) ────────────────────────────────────────
C3  = 130.81;  F3  = 174.61;  G3  = 196.00;  Bb3 = 233.08
C4  = 261.63;  Eb4 = 311.13;  F4  = 349.23;  G4  = 392.00;  Bb4 = 466.16
C5  = 523.25;  Eb5 = 622.25;  F5  = 698.46;  G5  = 783.99

# ── Osciladores ───────────────────────────────────────────────────────────────

def _square(freq, n, duty=0.5):
    """Onda quadrada — som chiptune clássico."""
    import numpy as np
    period = SAMPLE_RATE / freq
    t = np.arange(n)
    return AMPLITUDE * np.where((t % period) / period < duty, 1.0, -1.0)


def _triangle(freq, n):
    """Onda triangular — som mais suave para o baixo."""
    import numpy as np
    t = np.arange(n) / SAMPLE_RATE
    phase = (t * freq) % 1.0
    wave = 2.0 * np.abs(2.0 * phase - 1.0) - 1.0
    return AMPLITUDE * 0.7 * wave


def _noise(n, decay=3000):
    """Ruído com decay — percussão simples."""
    import numpy as np
    burst = np.random.uniform(-1.0, 1.0, n)
    env   = np.exp(-np.arange(n) / decay)
    return AMPLITUDE * 0.5 * burst * env


def _envelope(signal, attack=200, release=800):
    """Aplica attack/release ao sinal."""
    import numpy as np
    n = len(signal)
    env = np.ones(n)
    att = min(attack, n // 4)
    rel = min(release, n // 2)
    if att > 0:
        env[:att] = np.linspace(0, 1, att)
    if rel > 0:
        env[-rel:] = np.linspace(1, 0, rel)
    return signal * env

# ── Construtores de partes ─────────────────────────────────────────────────────

def _note(freq, sixteenths, osc='square'):
    """Gera uma nota com duração em colcheias."""
    import numpy as np
    n = sixteenths * _SIXTEEN
    legato = int(n * 0.85)   # 15% de silêncio entre notas
    if osc == 'square':
        body = _square(freq, legato)
    else:
        body = _triangle(freq, legato)
    body = _envelope(body)
    full = np.zeros(n)
    full[:legato] = body
    return full


def _rest(sixteenths):
    import numpy as np
    return np.zeros(sixteenths * _SIXTEEN)


def _kick(sixteenths=2):
    """Kick drum: sweep de frequência rápido."""
    import numpy as np
    n = sixteenths * _SIXTEEN
    freq_sweep = np.linspace(180, 40, n)
    t  = np.cumsum(freq_sweep) / SAMPLE_RATE
    body = AMPLITUDE * 0.9 * np.sin(2 * np.pi * t)
    env  = np.exp(-np.arange(n) / (_SIXTEEN * 0.8))
    return body * env


def _hihat(sixteenths=1, open_hat=False):
    """Hi-hat: ruído filtrado."""
    decay = _SIXTEEN * 2.5 if open_hat else _SIXTEEN * 0.6
    return _noise(sixteenths * _SIXTEEN, decay=int(decay))

# ── Composição dos 4 compassos ─────────────────────────────────────────────────

def _build_melody():
    """Melodia principal — 4 compassos, linha superior."""
    import numpy as np
    # Cada compasso tem 16 semicolcheias (16th notes)
    # (nota, duração_em_16avos)
    bars = [
        # Compasso 1
        [C5,2, G4,2, Bb4,2, C5,2,  Eb5,2, C5,2, G4,4],
        # Compasso 2
        [F5,2, Eb5,2, C5,2, Bb4,2, G4,2, Bb4,2, C5,4],
        # Compasso 3
        [G5,2, F5,2, Eb5,2, C5,2,  Eb5,2, G4,2, Bb4,4],
        # Compasso 4
        [C5,4, Eb5,4, G5,4, F5,4],
    ]
    parts = []
    for bar in bars:
        seg = []
        it = iter(bar)
        for freq, dur in zip(it, it):
            if freq == 0:
                seg.append(_rest(dur))
            else:
                seg.append(_note(freq, dur, osc='square'))
        parts.append(np.concatenate(seg))
    return np.concatenate(parts)


def _build_bass():
    """Linha de baixo — 4 compassos, oitava abaixo."""
    import numpy as np
    # (nota, beats em 16avos)
    bars = [
        [C3,8,  G3,8],
        [F3,8,  Bb3,8],
        [C3,8,  G3,8],
        [F3,8,  C3,8],
    ]
    parts = []
    for bar in bars:
        seg = []
        it = iter(bar)
        for freq, dur in zip(it, it):
            seg.append(_note(freq, dur, osc='triangle'))
        parts.append(np.concatenate(seg))
    return np.concatenate(parts)


def _build_drums():
    """Batida simples — kick + hi-hat."""
    import numpy as np
    # Padrão de 1 compasso: kick nos beats 1 e 3, hi-hat em todos os 8avos
    bar_samples = 16 * _SIXTEEN
    pattern = np.zeros(bar_samples)

    # Kick no beat 1 (pos 0) e beat 3 (pos 8)
    for pos in [0, 8]:
        k = _kick(sixteenths=2)
        end = min(pos * _SIXTEEN + len(k), bar_samples)
        pattern[pos * _SIXTEEN: end] += k[:end - pos * _SIXTEEN]

    # Hi-hat a cada 2 semicolcheias (8avos)
    for pos in range(0, 16, 2):
        h = _hihat(sixteenths=1)
        end = min(pos * _SIXTEEN + len(h), bar_samples)
        pattern[pos * _SIXTEEN: end] += h[:end - pos * _SIXTEEN]

    return np.tile(pattern, 4)   # 4 compassos

# ── Mix e exportação ───────────────────────────────────────────────────────────

def generate(output_path='assets/music/bg_music.wav'):
    """Gera o arquivo WAV de música de fundo."""
    import numpy as np

    melody = _build_melody()
    bass   = _build_bass()
    drums  = _build_drums()

    # Garante mesmo tamanho
    n = max(len(melody), len(bass), len(drums))
    def pad(a): return np.pad(a, (0, n - len(a)))
    mix = pad(melody) * 0.55 + pad(bass) * 0.35 + pad(drums) * 0.10

    # Normaliza e adiciona fade-in/fade-out suave nas pontas do loop
    peak = np.max(np.abs(mix)) or 1.0
    mix  = mix / peak * 0.85
    fade = min(2205, n // 10)   # 50ms de fade
    mix[:fade]  *= np.linspace(0, 1, fade)
    mix[-fade:] *= np.linspace(1, 0, fade)

    # Converte para PCM 16-bit
    pcm = (mix * 32767).astype(np.int16)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with wave.open(output_path, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm.tobytes())

    print(f'[music_gen] Musica gerada: {output_path}')


if __name__ == '__main__':
    generate()
