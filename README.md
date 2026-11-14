# Efootdls

Projeto original de jogo de futebol 3D para Android, desenvolvido em Godot 4.

## Estado atual
- Lobby inicial com cenário 3D de estádio criado proceduralmente.
- Interface adaptável com perfil, moedas e atalhos.
- Botões de Partida, Dream Team, Meu Elenco, Loja e Evento.
- Base preparada para adicionar partidas, jogadores, formações e modos online.

> Esta é a primeira etapa jogável do projeto: o lobby e os botões de navegação estão implementados. As telas e os modos indicados nos botões ainda serão desenvolvidos.

## Como abrir
1. Instale o Godot 4.3 ou superior.
2. Abra o Godot e selecione **Importar**.
3. Escolha este repositório/pasta e abra o arquivo `project.godot`.
4. Execute o projeto com F6/F5.

## Android
O projeto usa o renderizador Compatibility para ampliar a compatibilidade com dispositivos móveis. Para gerar APK, configure o Android SDK e os templates de exportação no Godot e use **Projeto > Exportar > Android**.

## Render
O Render pode hospedar serviços web e uma versão web exportada do jogo. Ele não compila diretamente este projeto Godot para APK. A exportação Android é feita pelo Godot.
