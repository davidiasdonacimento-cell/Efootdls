import './style.css';
import { startGame } from './engine.js';

const root = document.querySelector('#app');
root.innerHTML = `
  <div class="shell">
    <header class="topbar">
      <a class="brand" href="#" aria-label="Efootdls início"><img class="brand-mark" src="/logo.svg" alt="Efootdls"><span><b>EFOOTDLS</b><small>FOOTBALL SIMULATOR</small></span></a>
      <div class="top-right"><span class="online"><i></i> MATCH CENTER</span><button class="sound-toggle" id="sound" aria-label="Som">♫</button></div>
    </header>
    <main>
      <section class="heading"><div><span class="kicker">MODO EXIBIÇÃO · TEMPORADA 2026</span><h1>PARTIDA RÁPIDA</h1></div><div class="league">★ <span>EFOOTDLS CHAMPIONS CUP</span></div></section>
      <section class="stadium-ui">
        <div class="scorebar">
          <div class="team"><span class="crest crest-home">E</span><span>BLUE WOLVES</span></div>
          <div class="score-wrap"><strong id="home-score">0</strong><span>:</span><strong id="away-score">0</strong><small id="clock">00:00</small></div>
          <div class="team away"><span>RED TITANS</span><span class="crest crest-away">R</span></div>
        </div>
        <div class="viewport" id="viewport">
          <div class="loading" id="loading"><div class="loader"></div><b>PREPARANDO O ESTÁDIO</b><small>Carregando motor 3D</small></div>
          <div class="goal-toast" id="goal-toast">GOOOOOOL!</div>
          <div class="camera-label">EFOOTDLS BROADCAST CAM <span>● REC</span></div>
          <div class="start-screen" id="start-screen"><div class="start-panel"><span class="kicker">O GRAMADO É SEU</span><h2>FAÇA HISTÓRIA.</h2><p>Entre em campo, domine a bola e vença a partida.</p><button class="primary" id="play">▶ &nbsp; COMEÇAR PARTIDA</button></div></div>
          <div class="pause-screen hidden" id="pause-screen"><div class="start-panel"><h2>PARTIDA PAUSADA</h2><button class="primary" id="resume">CONTINUAR</button></div></div>
        </div>
        <div class="match-meta"><span><i class="green-dot"></i> AMISTOSO</span><span>ESTÁDIO EFOOTDLS</span><span id="period">1º TEMPO</span></div>
      </section>
      <section class="below">
        <div class="hint"><b>CONTROLES</b><span>WASD / SETAS — MOVER</span><span>ESPAÇO — CHUTAR</span></div>
        <div class="actions"><button id="pause" class="secondary">Ⅱ PAUSAR</button><button id="reset" class="secondary">↻ REINICIAR</button></div>
      </section>
      <section class="touch-controls">
        <div class="pad" id="pad"><button data-x="0" data-y="-1">▲</button><button data-x="-1" data-y="0">◀</button><button data-x="0" data-y="1">▼</button><button data-x="1" data-y="0">▶</button></div>
        <button class="kick" id="kick">⚡<small>CHUTAR</small></button>
      </section>
    </main>
    <footer><span>© 2026 EFOOTDLS</span><span>THREE.JS ENGINE · CSS · C++ / WEBASSEMBLY READY</span></footer>
  </div>`;
const game = startGame(document.querySelector('#viewport'), {
  onScore(team, score) {
    document.querySelector(team === 'home' ? '#home-score' : '#away-score').textContent = score;
    const toast = document.querySelector('#goal-toast');
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 1700);
  },
  onReady() { document.querySelector('#loading').classList.add('hidden'); }
});
const start = () => { game.start(); document.querySelector('#start-screen').classList.add('hidden'); };
document.querySelector('#play').addEventListener('click', start);
document.querySelector('#pause').addEventListener('click', () => {
  const paused = game.togglePause();
  document.querySelector('#pause').textContent = paused ? '▶ CONTINUAR' : 'Ⅱ PAUSAR';
  document.querySelector('#pause-screen').classList.toggle('hidden', !paused);
});
document.querySelector('#resume').addEventListener('click', () => {
  game.togglePause(false);
  document.querySelector('#pause-screen').classList.add('hidden');
  document.querySelector('#pause').textContent = 'Ⅱ PAUSAR';
});
document.querySelector('#reset').addEventListener('click', () => {
  game.reset();
  document.querySelector('#home-score').textContent = '0';
  document.querySelector('#away-score').textContent = '0';
  document.querySelector('#clock').textContent = '00:00';
  document.querySelector('#pause-screen').classList.add('hidden');
  document.querySelector('#start-screen').classList.remove('hidden');
});
document.querySelector('#kick').addEventListener('pointerdown', e => { e.preventDefault(); game.kick(); });
document.querySelectorAll('#pad button').forEach(button => {
  const x = Number(button.dataset.x), y = Number(button.dataset.y);
  button.addEventListener('pointerdown', e => { e.preventDefault(); button.setPointerCapture(e.pointerId); game.move(x,y); });
  for (const event of ['pointerup','pointercancel','lostpointercapture']) button.addEventListener(event, () => game.move(0,0));
});
document.querySelector('#sound').addEventListener('click', () => {
  const button = document.querySelector('#sound');
  button.classList.toggle('muted');
  button.textContent = button.classList.contains('muted') ? '×' : '♫';
});
