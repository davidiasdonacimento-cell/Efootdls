# Efootdls Web 3D

Jogo de futebol para navegador, com motor **Three.js puro**, sem React.

## Tecnologias
- JavaScript ES Modules + Vite
- Three.js para renderização 3D
- CSS para interface responsiva e controles mobile
- C++ com Emscripten/WebAssembly para rotinas nativas opcionais
- Python exclusivamente para APIs/backend (Flask, Django ou FastAPI)

## Executar
```bash
cd web
npm install
npm run dev
```

## Build
```bash
npm run build
```

## C++ / WebAssembly
O código nativo de física está em `cpp/physics.cpp`. Para compilar com Emscripten:
```bash
em++ cpp/physics.cpp -O3 -s WASM=1 -s EXPORTED_FUNCTIONS='["_efootdls_step_ball"]' -s EXPORTED_RUNTIME_METHODS='[]' -o web/public/physics.js
```
O jogo mantém fallback JavaScript; a compilação WASM é opcional e não bloqueia o build estático do Render.

## Render Static Site
- Root Directory: `web`
- Build Command: `npm install && npm run build`
- Publish Directory: `dist`

A cena atual usa jogadores procedurais articulados, campo e estádio 3D, arquibancadas com torcida instanciada, iluminação, câmera de transmissão, placar e controles touch/teclado. Modelos profissionais licenciados em GLB/GLTF, animações completas, IA tática e multiplayer ainda precisam ser adicionados; não são declarados como concluídos.
