import * as THREE from 'three';

const FIELD_W = 70, FIELD_L = 108;
const clamp = THREE.MathUtils.clamp;
const mat = (color, roughness=.8) => new THREE.MeshStandardMaterial({color, roughness});
function box(parent, w,h,d, material, x,y,z) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(w,h,d), material);
  mesh.position.set(x,y,z); mesh.castShadow = true; mesh.receiveShadow = true; parent.add(mesh); return mesh;
}
function makePlayer(teamColor, skinColor, number, keeper=false) {
  const group = new THREE.Group();
  const shirt=mat(teamColor), shorts=mat(keeper?'#20242d':'#101923'), socks=mat(teamColor), skin=mat(skinColor), boots=mat('#101318');
  const torso= new THREE.Mesh(new THREE.CapsuleGeometry(.43,.72,5,10),shirt); torso.position.y=1.42; torso.castShadow=true; group.add(torso);
  const head=new THREE.Mesh(new THREE.SphereGeometry(.25,18,14),skin); head.position.y=2.12; head.castShadow=true; group.add(head);
  const hair=new THREE.Mesh(new THREE.SphereGeometry(.255,16,10,0,Math.PI*2,0,Math.PI*.52),mat('#17191c')); hair.position.y=2.2; group.add(hair);
  const shortsMesh=box(group,.72,.36,.4,shorts,0,.92,0);
  const legs=[];
  for (const side of [-1,1]) {
    const pivot=new THREE.Group(); pivot.position.set(side*.22,.82,0); group.add(pivot);
    const leg=new THREE.Mesh(new THREE.CapsuleGeometry(.13,.62,4,8),skin); leg.position.y=-.39; leg.castShadow=true; pivot.add(leg);
    const sock=new THREE.Mesh(new THREE.CylinderGeometry(.115,.13,.35,10),socks); sock.position.set(0,-.67,0); pivot.add(sock);
    const boot=new THREE.Mesh(new THREE.BoxGeometry(.2,.13,.38),boots); boot.position.set(0,-.87,-.08); pivot.add(boot);
    legs.push(pivot);
  }
  const arms=[];
  for(const side of [-1,1]){
    const arm=new THREE.Mesh(new THREE.CapsuleGeometry(.105,.55,4,8),shirt);
    arm.position.set(side*.52,1.48,0); arm.rotation.z=side*-.18; group.add(arm); arms.push(arm);
  }
  const badge= new THREE.Mesh(new THREE.CircleGeometry(.12,16),mat('#f4f5f7')); badge.position.set(0,1.48,.421); group.add(badge);
  group.userData={legs,arms,number,phase:Math.random()*6,velocity:new THREE.Vector3()};
  return group;
}
function addStadium(scene) {
  const grass=mat('#176b3c'), stripeA=mat('#1d8248'), stripeB=mat('#176f40'), white=mat('#eaf4ed');
  box(scene,FIELD_W,.5,FIELD_L,grass,0,-.5,0);
  for(let i=0;i<18;i++) box(scene,FIELD_W-.5,.012,FIELD_L/18-.02,i%2?stripeA:stripeB,0,-.238,-FIELD_L/2+(i+.5)*FIELD_L/18);
  const lineMat=new THREE.LineBasicMaterial({color:0xf4f7ef});
  const draw=(pts,closed=false)=>{
    const points=pts.map(p=>new THREE.Vector3(p[0],.012,p[1]));
    if(closed)points.push(points[0].clone());
    scene.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points),lineMat));
  };
  draw([[-34,-53],[34,-53],[34,53],[-34,53]],true); draw([[-34,0],[34,0]]);
  const circle=new THREE.Mesh(new THREE.RingGeometry(9.12,9.28,72),new THREE.MeshBasicMaterial({color:0xffffff,side:THREE.DoubleSide}));
  circle.rotation.x=-Math.PI/2; circle.position.y=.02; scene.add(circle);
  const dot=new THREE.Mesh(new THREE.CircleGeometry(.24,20),white); dot.rotation.x=-Math.PI/2; dot.position.y=.025; scene.add(dot);
  for(const z of [-53,53]){
    for(const w of [20,7.5]){
      const depth=w===20?16.5:5.5;
      draw([[-w,z],[ -w,z-Math.sign(z)*depth],[w,z-Math.sign(z)*depth],[w,z]]);
    }
    box(scene,7.32,2.45,.35,white,0,1.25,z);
    box(scene,7.48,.13,.5,white,0,2.53,z);
    for(const x of [-3.55,3.55])box(scene,.12,2.5,.6,white,x,1.25,z);
  }
  // Technical area, running track and stands.
  const track=mat('#7b3436');
  box(scene,FIELD_W+15,.15,FIELD_L+18,track,0,-.33,0);
  box(scene,FIELD_W+27,.3,FIELD_L+32,mat('#182632'),0,-.55,0);
  for(const side of [-1,1]){
    const standMat=mat('#263b4b');
    for(let row=0;row<9;row++){
      box(scene,18,.9,FIELD_L+25,standMat,side*(43+row*1.45),2.1+row*1.02,0);
    }
    box(scene,1,15,FIELD_L+30,mat('#101c27'),side*57,10,0);
  }
  // Crowd: colored low-poly spectators as dense dots in the grandstands.
  const crowdColors=[0xe7eaf0,0x2c9ee8,0xe54b55,0xf0c65a,0x273748];
  const crowdGeo=new THREE.SphereGeometry(.19,5,4);
  const crowdMat=crowdColors.map(c=>new THREE.MeshStandardMaterial({color:c,roughness:1}));
  for(const side of [-1,1]) for(let row=0;row<9;row++){
    const count=150;
    const inst=new THREE.InstancedMesh(crowdGeo,crowdMat[0],count);
    const dummy=new THREE.Object3D();
    for(let i=0;i<count;i++){
      dummy.position.set(side*(43+row*1.45)+(Math.random()-.5)*.7,2.7+row*1.02+(Math.random()-.5)*.45,(Math.random()-.5)*(FIELD_L+20));
      dummy.scale.set(.7,1.2,.7); dummy.updateMatrix(); inst.setMatrixAt(i,dummy.matrix);
      inst.setColorAt(i,new THREE.Color(crowdColors[Math.floor(Math.random()*crowdColors.length)]));
    }
    scene.add(inst);
  }
  // Stadium floodlight towers.
  for(const x of [-1,1])for(const z of [-1,1]){
    const px=x*61,pz=z*55;
    box(scene,.45,22,.45,mat('#b5c4cd'),px,11,pz);
    const lamp=box(scene,5,1,.5,mat('#f8f4d7'),px,22,pz);
    const light=new THREE.SpotLight(0xfff1cf,95,115,.8,.5,1.2); light.position.set(px,22,pz); light.target.position.set(0,0,0); scene.add(light,light.target);
  }
}
export function startGame(container, callbacks={}) {
  const scene=new THREE.Scene(); scene.background=new THREE.Color('#91b8cc'); scene.fog=new THREE.Fog('#91b8cc',105,190);
  const camera=new THREE.PerspectiveCamera(43,1,.1,300);
  camera.position.set(0,76,90); camera.lookAt(0,0,0);
  const renderer=new THREE.WebGLRenderer({antialias:true, powerPreference:'high-performance'});
  renderer.setPixelRatio(Math.min(devicePixelRatio,1.7)); renderer.shadowMap.enabled=true; renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  renderer.outputColorSpace=THREE.SRGBColorSpace; renderer.toneMapping=THREE.ACESFilmicToneMapping;
  container.appendChild(renderer.domElement);
  scene.add(new THREE.HemisphereLight(0xd9efff,0x36523d,2.1));
  const sun=new THREE.DirectionalLight(0xfff1d7,2.6); sun.position.set(-35,65,25); sun.castShadow=true; sun.shadow.mapSize.set(2048,2048); sun.shadow.camera.left=-80; sun.shadow.camera.right=80; sun.shadow.camera.top=100; sun.shadow.camera.bottom=-100; scene.add(sun);
  addStadium(scene);
  const players=[];
  const user=makePlayer('#087de0','#a66e4e',10); user.position.set(-5,0,22); scene.add(user); players.push(user);
  const homePositions=[[-20,15],[-8,8],[8,12],[21,19],[-22,-5],[-8,-12],[8,-9],[22,-2],[-2,-32],[0,43]];
  homePositions.forEach((p,i)=>{const a=makePlayer('#087de0',i%3?'#bd8968':'#8f5c43',i+2,i===9);a.position.set(p[0],0,p[1]);scene.add(a);players.push(a);});
  const awayPositions=[[-20,-19],[-9,-22],[9,-18],[21,-13],[-23,4],[-9,0],[9,5],[23,9],[0,30],[0,-44]];
  awayPositions.forEach((p,i)=>{const a=makePlayer('#dc3448',i%2?'#8f5c43':'#d09a72',i+1,i===9);a.position.set(p[0],0,p[1]);scene.add(a);players.push(a);});
  const ball=new THREE.Group();
  const sphere=new THREE.Mesh(new THREE.SphereGeometry(.48,24,18),mat('#f5f5ef',.4)); sphere.castShadow=true; ball.add(sphere);
  const seam=new THREE.Mesh(new THREE.TorusGeometry(.32,.018,5,24),mat('#222a32')); seam.rotation.x=Math.PI/2; ball.add(seam); ball.position.set(0,.55,17); scene.add(ball);
  const ballVelocity=new THREE.Vector3(), movement=new THREE.Vector2();
  let running=false,paused=false,scoreHome=0,scoreAway=0,elapsed=0,last=performance.now(),animation=0,raf=0;
  const clock=document.querySelector('#clock');
  function resize(){const w=container.clientWidth,h=container.clientHeight;camera.aspect=w/h;camera.updateProjectionMatrix();renderer.setSize(w,h,false);}
  const observer=new ResizeObserver(resize);observer.observe(container);resize();
  function move(x,y){movement.set(x,y);if(movement.length()>1)movement.normalize();}
  function kick(){if(!running||paused)return;const dir=new THREE.Vector3(ball.position.x-user.position.x,0,ball.position.z-user.position.z);if(dir.length()>3.3)return;if(dir.length()<.1)dir.set(0,0,-1);dir.normalize();ballVelocity.copy(dir.multiplyScalar(25));ballVelocity.y=5.5;}
  function reset(){scoreHome=0;scoreAway=0;elapsed=0;user.position.set(-5,0,22);ball.position.set(0,.55,17);ballVelocity.set(0,0,0);running=false;paused=false;}
  function tick(now){
    raf=requestAnimationFrame(tick);const dt=Math.min((now-last)/1000,.04);last=now;
    if(running&&!paused){
      elapsed+=dt;clock.textContent=new Date(elapsed*1000).toISOString().slice(14,19);
      const moving=movement.lengthSq()>.01;
      if(moving){user.position.x=clamp(user.position.x+movement.x*10*dt,-32,32);user.position.z=clamp(user.position.z+movement.y*10*dt,-51,51);}
      user.rotation.y=Math.atan2(movement.x,-movement.y)||user.rotation.y;
      animation+=dt*(moving?10:2);
      user.userData.legs[0].rotation.x=moving?Math.sin(animation)*.7:0;user.userData.legs[1].rotation.x=moving?-Math.sin(animation)*.7:0;
      user.userData.arms[0].rotation.z=-.18+(moving?Math.sin(animation)*.12:0);user.userData.arms[1].rotation.z=.18-(moving?Math.sin(animation)*.12:0);
      const distance=ball.position.distanceTo(new THREE.Vector3(user.position.x,.55,user.position.z));
      if(distance<1.7&&ballVelocity.length()<4){ballVelocity.x+=(user.position.x-ball.position.x)*dt*3;ballVelocity.z+=(user.position.z-ball.position.z)*dt*3;}
      ball.position.addScaledVector(ballVelocity,dt);ballVelocity.y-=17*dt;ball.position.y+=ballVelocity.y*dt;
      if(ball.position.y<.48){ball.position.y=.48;ballVelocity.y=Math.abs(ballVelocity.y)*.42;}
      ballVelocity.x*=Math.pow(.986,dt*60);ballVelocity.z*=Math.pow(.986,dt*60);ball.rotation.z-=ballVelocity.x*dt;ball.rotation.x+=ballVelocity.z*dt;
      if(Math.abs(ball.position.x)>34){ball.position.x=Math.sign(ball.position.x)*33.5;ballVelocity.x*=-.65;}
      if(Math.abs(ball.position.z)>53){
        if(Math.abs(ball.position.x)<3.65){
          if(ball.position.z<0){scoreHome++;callbacks.onScore?.('home',scoreHome);}else{scoreAway++;callbacks.onScore?.('away',scoreAway);}
          ball.position.set(0,.55,0);ballVelocity.set(0,0,0);
        }else{ball.position.z=Math.sign(ball.position.z)*52.5;ballVelocity.z*=-.65;}
      }
      // Broadcast camera smoothly tracks play while keeping the full tactical view.
      const targetX=user.position.x*.18+ball.position.x*.08;
      camera.position.x+=(targetX-camera.position.x)*dt*.6;
      camera.position.z+=(85-camera.position.z)*dt*.6;
      camera.lookAt(user.position.x*.12,0,0);
    }
    renderer.render(scene,camera);
  }
  raf=requestAnimationFrame(tick);callbacks.onReady?.();
  const keyDown=e=>{const k=e.key.toLowerCase();if(['arrowup','arrowdown','arrowleft','arrowright',' '].includes(k))e.preventDefault();if(k==='w'||k==='arrowup')move(movement.x,-1);if(k==='s'||k==='arrowdown')move(movement.x,1);if(k==='a'||k==='arrowleft')move(-1,movement.y);if(k==='d'||k==='arrowright')move(1,movement.y);if(k===' ')kick();};
  const keyUp=e=>{const k=e.key.toLowerCase();if(k==='w'||k==='arrowup'||k==='s'||k==='arrowdown')move(movement.x,0);if(k==='a'||k==='arrowleft'||k==='d'||k==='arrowright')move(0,movement.y);};
  window.addEventListener('keydown',keyDown);window.addEventListener('keyup',keyUp);
  return {
    start(){running=true;paused=false;},
    move,
    kick,
    togglePause(force){paused=typeof force==='boolean'?force:!paused;return paused;},
    reset,
    destroy(){cancelAnimationFrame(raf);observer.disconnect();window.removeEventListener('keydown',keyDown);window.removeEventListener('keyup',keyUp);renderer.dispose();container.removeChild(renderer.domElement);}
  };
}
