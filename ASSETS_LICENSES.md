# Efootdls — fontes dos recursos visuais

## Estádio 3D

- Arquivo carregado pelo jogo: `football-stadium.glb`
- Fonte: Innerscene 3D Parts Library — https://www.innerscene.com/tools/library/3d-parts/football-stadium-f7b93967
- Licença declarada pela página do modelo: CC0 1.0 (domínio público)
- O jogo baixa o GLB na primeira abertura com internet e guarda uma cópia em `user://efootdls_cache/football-stadium.glb`.
- Sem internet ou se o download falhar, o jogo mantém o estádio de reserva criado no projeto.

## Jogadores

Os jogadores em campo usam o script próprio `scripts/footballer_visual.gd`. A malha é montada proceduralmente com peças leves articuladas para evitar dependência de downloads externos durante a partida. A animação de corrida acompanha a velocidade do `CharacterBody3D`.

## Compatibilidade

Projeto direcionado ao Godot 4.7.2 e ao renderizador Compatibility para aparelhos móveis. A validação automatizada de importação e execução headless está configurada em `.github/workflows/godot-check.yml`. A aparência e o desempenho finais ainda precisam ser conferidos no aparelho Android.
