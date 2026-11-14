# Efootdls — linguagens e frameworks

O repositório mantém o frontend do jogo em React + Three.js. O Dockerfile da raiz fornece um ambiente amplo de desenvolvimento com os runtimes listados abaixo.

## Linguagens e runtimes no Docker

- Elixir — sistemas distribuídos
- Bun e Node.js — aplicações JavaScript
- PHP
- Java
- Kotlin
- Scala
- C#
- F#
- C
- C++
- Dart
- Perl
- R
- Lua
- Python

C# e F# usam o .NET SDK. C e C++ usam GCC/G++ e ferramentas de compilação.

## Frameworks de interface instalados no workspace JavaScript

- React
- Vue.js
- Angular
- Next.js
- Svelte
- Astro
- Vite

Esses frameworks são opções disponíveis no ambiente; o jogo atual continua usando React + Vite + Three.js. Não significa que todos os frameworks sejam usados simultaneamente na mesma tela.

## Backend e APIs

**Somente Python** é adotado para APIs/backend. O ambiente Python instala Flask, Django e FastAPI como opções. PHP, Java, Kotlin, Scala, C#, F#, C, C++, Dart, Perl, R, Lua, Elixir e Bun/Node não são configurados como servidores de API neste projeto.

## Usar o Docker

Na raiz do repositório:

```bash
docker build -t efootdls-dev .
docker run --rm -it -p 5173:5173 efootdls-dev
```

O ambiente de desenvolvimento abre o Vite em `http://localhost:5173`.

## Render

O serviço público do jogo continua sendo um **Render Static Site**, que publica o build React em `web/dist`. O Dockerfile é um ambiente opcional para desenvolvimento e não é instalado dentro do Static Site. Para executar um container no Render, seria necessário criar um serviço Docker separado; isso não é necessário para servir o frontend estático.
