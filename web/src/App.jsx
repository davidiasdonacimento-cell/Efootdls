import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { Line, OrbitControls, PerspectiveCamera, Sky } from '@react-three/drei';
import * as THREE from 'three';
import { Play, Pause, RotateCcw, Volume2, Trophy, Shield, Zap } from 'lucide-react';

const FIELD_W = 34;
const FIELD_H = 54;

function Markings() {
  const line = '#f4f7fa';
  const boundary = [[-FIELD_W/2,0,-FIELD_H/2],[FIELD_W/2,0,-FIELD_H/2],[FIELD_W/2,0,FIELD_H/2],[-FIELD_W/2,0,FIELD_H/2],[-FIELD_W/2,0,-FIELD_H/2]];
  const halfway = [[-FIELD_W/2,0,0],[FIELD_W/2,0,0]];
  const boxTop = [[-10,0,-FIELD_H/2],[-10,0,-18],[10,0,-18],[10,0,-FIELD_H/2]];
  const boxBottom = [[-10,0,FIELD_H/2],[-10,0,18],[10,0,18],[10,0,FIELD_H/2]];
  const smallTop = [[-4.5,0,-FIELD_H/2],[-4.5,0,-23],[4.5,0,-23],[4.5,0,-FIELD_H/2]];
  const smallBottom = [[-4.5,0,FIELD_H/2],[-4.5,0,23],[4.5,0,23],[4.5,0,FIELD_H/2]];
  return <group>
    {[boundary,halfway,boxTop,boxBottom,smallTop,smallBottom].map((p,i)=><Line key={i} points={p.map(v=>new THREE.Vector3(...v))} color={line} lineWidth={2} />)}
    <mesh rotation={[-Math.PI/2,0,0]} position={[0,.025,0]}><ringGeometry args={[8.9,9.08,64]} /><meshBasicMaterial color={line} /></mesh>
    <mesh rotation={[-Math.PI/2,0,0]} position={[0,.026,0]}><circleGeometry args={[.22,24]} /><meshBasicMaterial color={line} /></mesh>
    {[-1,1].map((side)=><group key={side} position={[0,0,side*26.5]}>
      <mesh position={[0,1.5,0]}><boxGeometry args={[7.5,3,.35]} /><meshStandardMaterial color="#e8edf3" /></mesh>
      <mesh position={[0,3.05,0]}><boxGeometry args={[7.7,.18,.5]} /><meshStandardMaterial color="#fff" /></mesh>
    </group>)}
  </group>;
}

function Stadium() {
  return <group>
    <mesh rotation={[-Math.PI/2,0,0]} position={[0,-.12,0]} receiveShadow><planeGeometry args={[FIELD_W,FIELD_H]} /><meshStandardMaterial color="#167b42" roughness={.94} /></mesh>
    {Array.from({length:13},(_,i)=><mesh key={i} rotation={[-Math.PI/2,0,0]} position={[0,-.105,-25+i*4.2]}><planeGeometry args={[FIELD_W,4.2]} /><meshStandardMaterial color={i%2?'#188449':'#14763d'} /></mesh>)}
    <Markings />
    <mesh rotation={[-Math.PI/2,0,0]} position={[0,-.35,0]}><planeGeometry args={[180,220]} /><meshStandardMaterial color="#111b25" /></mesh>
    {[-1,1].map((s)=><group key={s} position={[s*23,0,0]}>
      {[0,1,2,3,4,5].map((n)=><mesh key={n} position={[0,3+n*1.15,(n%2?1:-1)*5]}><boxGeometry args={[12,.75,1.1]} /><meshStandardMaterial color={n%2?'#243b53':'#304b65'} /></mesh>)}
    </group>)}
    <ambientLight intensity={1.35} />
    <directionalLight position={[-18,35,10]} intensity={2.1} castShadow shadow-mapSize-width={1024} shadow-mapSize-height={1024} />
  </group>;
}

function Player({position, color='#f5f7fa', active=false}) {
  return <group position={position}>
    <mesh position={[0,.72,0]} castShadow><capsuleGeometry args={[.34,.72,5,10]} /><meshStandardMaterial color={color} roughness={.7} /></mesh>
    <mesh position={[0,1.48,0]} castShadow><sphereGeometry args={[.25,16,16]} /><meshStandardMaterial color="#bd855f" /></mesh>
    {active&&<mesh position={[0,2.05,0]}><ringGeometry args={[.35,.48,32]} /><meshBasicMaterial color="#5de1ff" side={THREE.DoubleSide} /></mesh>}
  </group>;
}

function Ball({ballRef}) {
  return <mesh ref={ballRef} position={[0,.45,0]} castShadow>
    <sphereGeometry args={[.38,24,24]} /><meshStandardMaterial color="#f7f7f4" roughness={.45} />
  </mesh>;
}

function MatchScene({input, kickSignal, paused, score, setScore, onGoal}) {
  const playerRef=useRef();
  const ballRef=useRef();
  const velocity=useRef(new THREE.Vector3());
  const lastKick=useRef(kickSignal);
  const goalCooldown=useRef(0);
  useFrame((_,delta)=>{
    if(paused||!playerRef.current||!ballRef.current)return;
    const dt=Math.min(delta,.04);
    const p=playerRef.current.position;
    const move=new THREE.Vector3(input.current.x,0,input.current.y);
    if(move.lengthSq()>1)move.normalize();
    p.x=THREE.MathUtils.clamp(p.x+move.x*8*dt,-FIELD_W/2+1,FIELD_W/2-1);
    p.z=THREE.MathUtils.clamp(p.z+move.z*8*dt,-FIELD_H/2+1,FIELD_H/2-1);
    const b=ballRef.current.position;
    const dist=Math.hypot(b.x-p.x,b.z-p.z);
    if(dist<1.7 && velocity.current.length()<1.4){
      velocity.current.x+=(p.x-b.x)*dt*2;
      velocity.current.z+=(p.z-b.z)*dt*2;
    }
    if(kickSignal!==lastKick.current){
      lastKick.current=kickSignal;
      if(dist<3.2){
        const direction=new THREE.Vector3(b.x-p.x,0,b.z-p.z);
        if(direction.length()<.1) direction.set(0,0,-1);
        direction.normalize();
        velocity.current.copy(direction.multiplyScalar(17));
        velocity.current.y=4;
      }
    }
    b.x+=velocity.current.x*dt; b.z+=velocity.current.z*dt;
    velocity.current.x*=Math.pow(.985,dt*60); velocity.current.z*=Math.pow(.985,dt*60);
    velocity.current.y-=15*dt;
    b.y+=velocity.current.y*dt;
    if(b.y<.38){b.y=.38;velocity.current.y=Math.abs(velocity.current.y)*.48;}
    if(Math.abs(b.x)>FIELD_W/2-0.5){b.x=Math.sign(b.x)*(FIELD_W/2-.5);velocity.current.x*=-.65;}
    if(Math.abs(b.z)>FIELD_H/2-0.5){
      if(Math.abs(b.x)<4 && goalCooldown.current<=0){
        if(b.z<0)setScore(v=>({...v,home:v.home+1})); else setScore(v=>({...v,away:v.away+1}));
        onGoal(); goalCooldown.current=2.5; b.set(0,.45,0); velocity.current.set(0,0,0);
      } else {b.z=Math.sign(b.z)*(FIELD_H/2-.5);velocity.current.z*=-.65;}
    }
    goalCooldown.current=Math.max(0,goalCooldown.current-dt);
    ballRef.current.rotation.x+=velocity.current.z*dt*1.7;
    ballRef.current.rotation.z-=velocity.current.x*dt*1.7;
  });
  return <group>
    <Stadium />
    <group ref={playerRef} position={[0,0,13]}><Player position={[0,0,0]} color="#19a7ff" active /></group>
    {[-1,1].map((s)=><React.Fragment key={s}>
      {[-1,0,1].map((x,i)=><Player key={i} position={[x*7,0,s*(i===1?9:16)]} color={s===-1?'#eaf1f7':'#e34c5b'} />)}
    </React.Fragment>)}
    <Ball ballRef={ballRef} />
    <PerspectiveCamera makeDefault position={[0,36,47]} fov={43} />
    <OrbitControls enablePan={false} enableZoom={false} minPolarAngle={.45} maxPolarAngle={.85} target={[0,0,0]} />
    <Sky distance={450000} sunPosition={[30,80,20]} inclination={.5} azimuthal={.25} />
  </group>;
}

export default function App(){
  const input=useRef({x:0,y:0});
  const [started,setStarted]=useState(false);
  const [paused,setPaused]=useState(false);
  const [kickSignal,setKickSignal]=useState(0);
  const [score,setScore]=useState({home:0,away:0});
  const [message,setMessage]=useState('TOQUE EM JOGAR PARA COMEÇAR');
  const pointer=useRef(null);
  const setMove=(x,y)=>{input.current={x,y};};
  const kick=()=>setKickSignal(v=>v+1);
  const reset=()=>{setScore({home:0,away:0});setPaused(false);setStarted(true);setMessage('PARTIDA EM ANDAMENTO');};
  useEffect(()=>{
    const down=e=>{const k=e.key.toLowerCase();if(k==='w'||k==='arrowup')input.current.y=-1;if(k==='s'||k==='arrowdown')input.current.y=1;if(k==='a'||k==='arrowleft')input.current.x=-1;if(k==='d'||k==='arrowright')input.current.x=1;if(k===' ')kick();};
    const up=e=>{if(['w','arrowup','s','arrowdown'].includes(e.key.toLowerCase()))input.current.y=0;if(['a','arrowleft','d','arrowright'].includes(e.key.toLowerCase()))input.current.x=0;};
    window.addEventListener('keydown',down);window.addEventListener('keyup',up);
    return()=>{window.removeEventListener('keydown',down);window.removeEventListener('keyup',up);};
  },[]);
  const onGoal=useCallback(()=>{setMessage('GOOOOL!');setTimeout(()=>setMessage('PARTIDA EM ANDAMENTO'),1800);},[]);
  return <main className="app-shell">
    <header className="topbar"><div className="brand"><span className="brand-mark">E</span><div><strong>EFOOTDLS</strong><small>FOOTBALL 3D</small></div></div><div className="top-actions"><span className="live-dot">● LIVE MATCH</span><button className="icon-button" aria-label="Som"><Volume2 size={18}/></button></div></header>
    <section className="match-heading"><div><span className="eyebrow">MODO EXIBIÇÃO</span><h1>Partida rápida</h1></div><div className="competition"><Trophy size={17}/> EFOOTDLS CUP</div></section>
    <section className="game-frame">
      <div className="scoreboard"><div className="team"><span className="crest blue">E</span><span>AZUL FC</span></div><div className="score">{score.home}<i>:</i>{score.away}</div><div className="team away"><span>RED UNITED</span><span className="crest red">R</span></div></div>
      <div className="canvas-wrap"><Canvas shadows dpr={[1,1.5]} gl={{antialias:true, powerPreference:'high-performance'}}><color attach="background" args={['#8bb8d0']} /><MatchScene input={input} kickSignal={kickSignal} paused={paused||!started} score={score} setScore={setScore} onGoal={onGoal}/></Canvas>
        {!started&&<div className="start-overlay"><div className="start-card"><span className="eyebrow">SEU JOGO COMEÇA AQUI</span><h2>Entre em campo.</h2><p>Controle seu jogador e marque o primeiro gol.</p><button className="primary-button" onClick={()=>{setStarted(true);setMessage('PARTIDA EM ANDAMENTO')}}><Play size={18} fill="currentColor"/> JOGAR AGORA</button></div></div>}
        {started&&<div className="match-status">{message}</div>}
      </div>
      <div className="match-footer"><span><span className="live-dot">●</span> 1º TEMPO</span><span>90:00</span><span>ESTÁDIO EFOOTDLS</span></div>
    </section>
    <section className="control-row">
      <div className="tips"><Shield size={17}/><span>WASD / SETAS para mover · ESPAÇO para chutar</span></div>
      <div className="desktop-actions"><button className="secondary-button" onClick={()=>setPaused(v=>!v)}><Pause size={16}/>{paused?'CONTINUAR':'PAUSAR'}</button><button className="secondary-button" onClick={reset}><RotateCcw size={16}/> REINICIAR</button></div>
    </section>
    <section className="mobile-controls">
      <div className="dpad" onPointerUp={()=>setMove(0,0)} onPointerLeave={()=>setMove(0,0)}>
        <button className="up" onPointerDown={e=>{e.preventDefault();setMove(0,-1)}}>▲</button>
        <button className="left" onPointerDown={e=>{e.preventDefault();setMove(-1,0)}}>◀</button>
        <button className="down" onPointerDown={e=>{e.preventDefault();setMove(0,1)}}>▼</button>
        <button className="right" onPointerDown={e=>{e.preventDefault();setMove(1,0)}}>▶</button>
      </div>
      <button className="kick-button" onPointerDown={kick}><Zap size={23} fill="currentColor"/>CHUTAR</button>
    </section>
    <footer><span>© 2026 EFOOTDLS</span><span>WEB 3D ENGINE · REACT + THREE.JS</span></footer>
  </main>;
}
