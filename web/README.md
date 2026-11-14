# Efootdls Web 3D

Frontend independente do projeto Godot, construído com React, Vite, Three.js e React Three Fiber.

## Requisitos
- Node.js 20.19+ ou 22.12+
- npm

## Desenvolvimento
```bash
cd web
npm install
npm run dev
```

## Build de produção
```bash
npm run build
npm run preview
```

O build é gerado em `web/dist`. A cena atual contém campo 3D procedural, câmera elevada estilo transmissão, placar, jogador controlável, bola com movimento/chute, controles de teclado e controles touch. É uma base jogável inicial; modelos humanos rigados, animações de futebol, IA tática e multiplayer ainda precisam ser integrados e testados.

## Render Static Site
- Root Directory: `web`
- Build Command: `npm install && npm run build`
- Publish Directory: `dist`
