# Efootdls

Jogo original de futebol 3D para Android, desenvolvido em Godot 4.3 com o renderizador Compatibility.

## Estrutura do projeto

- `project.godot`: configurações principais e cena de inicialização.
- `scenes/main.tscn`: cena que inicia a partida.
- `scenes/lobby.tscn`: cena de menu/lobby original.
- `scripts/match.gd`: coordena a partida, controles, HUD e ligação dos sistemas.
- `scripts/footballer_ai.gd`: comportamento dos atletas de apoio e adversários.
- `scripts/goalkeeper_ai.gd`: posicionamento e defesa do goleiro.
- `scripts/ball_physics.gd`: chute, passe, curva, velocidade e limites da bola.
- `scripts/match_clock.gd`: cronômetro, dois tempos, intervalo e pausa.
- `scripts/match_rules.gd`: fases, gols, reinícios e eventos de regra.
- `scripts/match_stats.gd`: estatísticas de jogo e histórico de eventos.
- `scripts/tactics_manager.gd`: tática equilibrada, ofensiva, defensiva e pressão.
- `scripts/camera_rig.gd`: câmera de acompanhamento com zoom e suavização.
- `scripts/minimap_overlay.gd`: mapa compacto com atletas e bola.
- `scripts/weather_system.gd`: variações de iluminação e condições climáticas.
- `scripts/profile_store.gd`: perfil e progresso salvos no armazenamento local.
- `scripts/career_manager.gd`: calendário de campeonato, resultados e classificação.
- `scripts/roster_manager.gd`: escalação, reservas, formação e substituições.
- `scripts/formation_catalog.gd`: catálogo de formações e posições.
- `scripts/player_attributes.gd`: atributos, overall, condicionamento e evolução.
- `scripts/training_manager.gd`: atividades de treino e pontuação.
- `scripts/achievement_manager.gd`: conquistas e recompensas.
- `scripts/match_feedback.gd`: comentários curtos para ações da partida.
- `scripts/match_settings.gd`: parâmetros e dificuldade.
- `scripts/lobby.gd`: construção visual do lobby.

## Controles da partida

| Controle | Ação |
| --- | --- |
| Joystick esquerdo | Movimentar o jogador |
| CORRER | Segurar para acelerar; a barra de fôlego diminui |
| CHUTAR | Chutar em direção ao gol |
| PASSE | Passar para o companheiro disponível mais próximo |
| DESARME | Tentar recuperar a bola de um adversário próximo |
| TÁTICA | Alternar entre equilíbrio, ataque, defesa e pressão |
| PAUSAR | Pausar ou continuar a partida |

Também há suporte a WASD/setas e Shift em computadores.

## Sistemas disponíveis no código

A partida constrói o gramado e o estádio em 3D, cria o atleta controlado, companheiros, adversários e goleiro, acompanha a bola com física 3D e mostra o placar e cronômetro. O HUD inclui minimapa, fôlego, botões de ação e seletor de tática.

O relógio utiliza dois períodos e intervalo. O perfil, carreira e conquistas usam arquivos `user://` do Godot, separados do repositório. Assim, dados pessoais de jogo não são enviados ao GitHub.

Os sistemas de escalação, carreira, treino, atributos e clima estão organizados em scripts próprios para permitir expansão sem concentrar tudo em um único arquivo.

## Abrir no Godot

1. Instale Godot 4.3 ou versão 4.x compatível.
2. Baixe o repositório como ZIP ou clone-o.
3. No Godot, selecione **Importar** e escolha a pasta que contém `project.godot`.
4. Aguarde a importação e execute com **F6** ou **F5**.

## Android

O projeto foi configurado em orientação horizontal e usa o renderizador Compatibility para ampliar a compatibilidade com dispositivos móveis.

Para exportar APK, configure no Godot o Android SDK, JDK e os templates de exportação. Depois use **Projeto > Exportar > Android**. O APK ainda precisa ser gerado e testado em um aparelho Android real.

## Verificação automatizada

O workflow em `.github/workflows/godot-check.yml` abre o projeto em modo headless para verificar se o Godot consegue importar e analisar os scripts. O resultado aparece na aba **Actions** do GitHub.

Uma validação automatizada não substitui testes de toque, desempenho, física e exportação em Android.

## Hospedagem

O Render pode hospedar uma versão Web exportada ou serviços de apoio. Ele não converte diretamente a pasta do projeto Godot em APK Android.
