import pygame
import random
from sys import exit

pygame.init()

current_state = "IDLE"
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption('Beat by Bit')
clock = pygame.time.Clock()
velocity = 4
trilhas = [250, 350, 450, 550]
cores = ['yellow', 'blue', 'green', 'red']
notas_criadas = []


def cria_notas():
    botao = random.randint(0, 3)
    nova_nota = {
        'botao': botao,
        'x': trilhas[botao],
        'y': -50,
        'cor': cores[botao]
    }
    notas_criadas.append(nova_nota)


def get_image(sheet, x, y, width, height):
    return sheet.subsurface((x, y, width, height))


def get_font(size):
    return pygame.font.Font('assets/fonts/Pixeltype.ttf', size)


def idle():
    screen.fill((0, 0, 0))
    idle_text = get_font(60).render(
        'Aperte start para jogar.', False, 'yellow')
    screen.blit(idle_text, (175, 300))
    game_name = get_font(120).render('Beat by Bit', False, 'Red')
    screen.blit(game_name, (200, 150))


def background():
    screen.fill((20, 20, 20))
    pygame.draw.line(screen, (255, 255, 255), (0, 500), (800, 500), 5)

def acerto(botao):
    for nota in notas_criadas:
        if nota['botao'] == botao:
            if abs(nota['y'] - 500) < 40:
                print('acerto')
                notas_criadas.remove(nota)


while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            pygame.quit()
            exit()

        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                print("START")
                if current_state == "IDLE":
                    current_state = "PLAY"
                elif current_state == "PLAY":
                    current_state = "PAUSE"
                elif current_state == "PAUSE":
                    current_state = "PLAY"

            if current_state == "PLAY":
                if event.key == pygame.K_d:
                    acerto(0)
                    print("Botao 1 - Amarelo")
                if event.key == pygame.K_f:
                    acerto(1)
                    print("Botao 2 - Azul")
                if event.key == pygame.K_j:
                    acerto(2)
                    print("Botao 3 - Verde")
                if event.key == pygame.K_k:
                    acerto(3)
                    print("Botao 4 - Vermelho")

    if current_state == "IDLE":
        idle()
    elif current_state == "PLAY":
        background()
        if random.random() < 0.04:
            cria_notas()
        for nota in notas_criadas[:]:
            nota['y'] += velocity
            pygame.draw.circle(screen, nota['cor'], (nota['x'], nota['y']), 20)

            if nota['y'] > 600:
                notas_criadas.remove(nota)
                print('erro')
    elif current_state == "PAUSE":
        pass

    pygame.display.flip()

    pygame.display.update()
    clock.tick(60)
