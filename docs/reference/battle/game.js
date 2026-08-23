// ============================================================
//  深渊幸存者 — 像素克苏鲁生存战斗
//  纯 Canvas 2D 实现，无外部依赖
// ============================================================

const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
ctx.imageSmoothingEnabled = false;

// ---- 视口 ----
let W = 0, H = 0;
function resize() {
  W = canvas.width = window.innerWidth;
  H = canvas.height = window.innerHeight;
  ctx.imageSmoothingEnabled = false;
}
window.addEventListener('resize', resize);
resize();

// ---- 输入 ----
const keys = {};
window.addEventListener('keydown', e => {
  keys[e.key.toLowerCase()] = true;
});
window.addEventListener('keyup', e => {
  keys[e.key.toLowerCase()] = false;
});

// ---- 工具 ----
const rand = (a, b) => a + Math.random() * (b - a);
const randi = (a, b) => Math.floor(rand(a, b));
const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const TAU = Math.PI * 2;

// ---- 像素工具 ----
function px(x, y, c, s = 1) {
  ctx.fillStyle = c;
  ctx.fillRect(Math.floor(x), Math.floor(y), s, s);
}

// ============================================================
//  世界 / 相机
// ============================================================
const WORLD = { w: 3000, h: 3000 };
const camera = { x: 0, y: 0 };

// ============================================================
//  玩家
// ============================================================
const player = {
  x: WORLD.w / 2,
  y: WORLD.h / 2,
  w: 20, h: 28,
  speed: 180,
  hp: 100, maxHp: 100,
  shield: 0, maxShield: 50,
  level: 1,
  exp: 0,
  expToNext: 10,
  gold: 0,
  bank: 3000,
  facing: 1, // 1右 -1左
  walkFrame: 0,
  walkTimer: 0,
  invuln: 0, // 无敌帧
  attackAngle: 0, // 旋转武器角度
  attackCooldown: 0,
  orbiting: [], // 环绕武器
};

// 初始环绕武器：一把镰刀
for (let i = 0; i < 2; i++) {
  player.orbiting.push({
    angle: (i / 2) * TAU,
    radius: 48,
    speed: 2.2,
    damage: 15,
    size: 10,
    hitCooldown: 0,
  });
}

// ============================================================
//  怪物
// ============================================================
const monsters = [];
const MONSTER_TYPES = {
  worm: { // 蠕虫：绿色蠕动
    w: 22, h: 14, hp: 30, speed: 45, damage: 8,
    exp: 2, gold: 3,
    color: ['#7fc47f', '#5a9a5a', '#3e7a3e', '#2a5a2a'],
  },
  tentacle: { // 触手怪
    w: 26, h: 26, hp: 55, speed: 35, damage: 14,
    exp: 4, gold: 6,
    color: ['#8a6ab0', '#6b4a8f', '#4a2e6b', '#2e1a4a'],
  },
  walker: { // 深渊行者
    w: 24, h: 32, hp: 80, speed: 55, damage: 18,
    exp: 6, gold: 10,
    color: ['#4a3a3a', '#2a2020', '#1a1414', '#0a0808'],
  },
  eye: { // 浮游眼
    w: 18, h: 18, hp: 20, speed: 70, damage: 6,
    exp: 2, gold: 4,
    color: ['#c48a8a', '#8a5a5a', '#5a3a3a', '#3a2020'],
  },
  slime: { // 深渊粘液
    w: 20, h: 16, hp: 40, speed: 30, damage: 10,
    exp: 3, gold: 5,
    color: ['#6fd3c4', '#4a9a8f', '#2e6b6b', '#1a4a4a'],
  },
};

function spawnMonster() {
  const types = Object.keys(MONSTER_TYPES);
  // 根据波次调整权重
  const wave = gameState.wave;
  let pool = [];
  pool.push('worm', 'worm', 'worm');
  if (wave >= 2) pool.push('eye', 'eye');
  if (wave >= 3) pool.push('slime', 'slime');
  if (wave >= 4) pool.push('tentacle');
  if (wave >= 5) pool.push('walker');
  if (wave >= 7) pool.push('tentacle', 'walker');

  const typeKey = pool[randi(0, pool.length)];
  const type = MONSTER_TYPES[typeKey];

  // 在屏幕外生成
  const side = randi(0, 4);
  const margin = 80;
  let x, y;
  if (side === 0) { x = camera.x - margin; y = camera.y + rand(0, H); }
  else if (side === 1) { x = camera.x + W + margin; y = camera.y + rand(0, H); }
  else if (side === 2) { x = camera.x + rand(0, W); y = camera.y - margin; }
  else { x = camera.x + rand(0, W); y = camera.y + H + margin; }

  x = clamp(x, 20, WORLD.w - 20);
  y = clamp(y, 20, WORLD.h - 20);

  const hpMult = 1 + (wave - 1) * 0.25;

  monsters.push({
    x, y,
    w: type.w, h: type.h,
    hp: Math.floor(type.hp * hpMult),
    maxHp: Math.floor(type.hp * hpMult),
    speed: type.speed + (wave - 1) * 3,
    damage: type.damage,
    exp: type.exp,
    gold: type.gold,
    typeKey,
    type,
    animTime: Math.random() * 2,
    hurtFlash: 0,
    knockback: { x: 0, y: 0 },
  });
}

// ============================================================
//  投射物
// ============================================================
const projectiles = []; // 玩家飞弹
const enemyProjectiles = [];

function shootProjectile(angle) {
  projectiles.push({
    x: player.x,
    y: player.y,
    vx: Math.cos(angle) * 320,
    vy: Math.sin(angle) * 320,
    damage: 12,
    life: 1.2,
    size: 5,
  });
}

// ============================================================
//  掉落物
// ============================================================
const drops = [];
function spawnDrop(x, y, type, value) {
  drops.push({
    x, y,
    vx: rand(-30, 30),
    vy: rand(-40, -10),
    type, // 'gold', 'exp', 'heart'
    value,
    life: 15,
    bobTime: Math.random() * 3,
    picked: false,
  });
}

// ============================================================
//  粒子
// ============================================================
const particles = [];
function spawnParticle(x, y, opts = {}) {
  particles.push({
    x, y,
    vx: opts.vx ?? rand(-60, 60),
    vy: opts.vy ?? rand(-60, 60),
    life: opts.life ?? rand(0.3, 0.8),
    maxLife: opts.life ?? 0.5,
    size: opts.size ?? rand(2, 4),
    color: opts.color ?? '#fff',
    gravity: opts.gravity ?? 0,
    type: opts.type ?? 'square',
  });
}

function explosion(x, y, color, count = 12) {
  for (let i = 0; i < count; i++) {
    const a = rand(0, TAU);
    const sp = rand(40, 160);
    spawnParticle(x, y, {
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp,
      life: rand(0.3, 0.7),
      size: rand(2, 5),
      color,
    });
  }
}

// ============================================================
//  雾气 / 环境粒子
// ============================================================
const fogParticles = [];
const runeLights = [];
const silhouettes = []; // 不可名状剪影

function initFog() {
  for (let i = 0; i < 40; i++) {
    fogParticles.push({
      x: rand(0, WORLD.w),
      y: rand(0, WORLD.h),
      size: rand(30, 80),
      vx: rand(-8, 8),
      vy: rand(-4, 4),
      alpha: rand(0.03, 0.08),
      phase: Math.random() * TAU,
    });
  }
  for (let i = 0; i < 8; i++) {
    runeLights.push({
      x: rand(100, WORLD.w - 100),
      y: rand(100, WORLD.h - 100),
      size: rand(6, 14),
      phase: Math.random() * TAU,
      speed: rand(0.3, 0.8),
    });
  }
  for (let i = 0; i < 5; i++) {
    silhouettes.push({
      x: rand(0, WORLD.w),
      y: rand(0, WORLD.h),
      size: rand(40, 90),
      vx: rand(-6, 6),
      vy: rand(-3, 3),
      alpha: 0,
      targetAlpha: 0,
      changeTimer: rand(3, 8),
    });
  }
}
initFog();

// ============================================================
//  游戏状态
// ============================================================
const gameState = {
  wave: 1,
  waveTime: 60, // 秒
  waveTimer: 60,
  spawnTimer: 0,
  spawnInterval: 1.5,
  screenShake: 0,
  levelupFlash: 0,
  waveTransition: 0,
};

// ============================================================
//  像素绘制：玩家
// ============================================================
function drawPlayer(px_, py_) {
  const f = Math.floor(player.walkFrame) % 4;
  const sway = [0, -1, 0, 1][f]; // 走路上下摆动
  const flash = player.invuln > 0 && Math.floor(player.invuln * 20) % 2 === 0;
  if (flash) return; // 闪烁

  const x = Math.floor(px_ - 10);
  const y = Math.floor(py_ - 14 + sway);

  // 像素艺术：绿衣兜帽冒险者
  // 颜色板
  const c = {
    hoodDark: '#3e6a3e',
    hood: '#5a8a4a',
    hoodLight: '#8fb36e',
    face: '#e8c8a0',
    faceShadow: '#b89878',
    cloak: '#4a7a3a',
    cloakDark: '#2e5a2a',
    belt: '#6b4a2a',
    boot: '#3a2a1a',
    eye: '#1a1a1a',
  };

  // 简化像素角色：正面视角（俯视角稍微斜一点）
  // 头（兜帽）
  ctx.fillStyle = c.hoodDark;
  ctx.fillRect(x + 4, y + 0, 12, 2);
  ctx.fillStyle = c.hood;
  ctx.fillRect(x + 3, y + 2, 14, 6);
  ctx.fillStyle = c.hoodLight;
  ctx.fillRect(x + 5, y + 2, 3, 2);
  ctx.fillRect(x + 4, y + 3, 1, 1);

  // 脸阴影
  ctx.fillStyle = c.faceShadow;
  ctx.fillRect(x + 5, y + 7, 10, 2);
  // 眼睛（黑缝）
  ctx.fillStyle = c.eye;
  ctx.fillRect(x + 7, y + 7, 2, 1);
  ctx.fillRect(x + 11, y + 7, 2, 1);

  // 身体/斗篷
  ctx.fillStyle = c.cloak;
  ctx.fillRect(x + 3, y + 9, 14, 8);
  ctx.fillStyle = c.cloakDark;
  ctx.fillRect(x + 3, y + 15, 14, 2);
  ctx.fillRect(x + 2, y + 11, 1, 4);
  ctx.fillRect(x + 17, y + 11, 1, 4);

  // 腰带
  ctx.fillStyle = c.belt;
  ctx.fillRect(x + 4, y + 13, 12, 1);

  // 腿
  const legOffset = f === 1 ? 1 : (f === 3 ? -1 : 0);
  ctx.fillStyle = c.cloakDark;
  ctx.fillRect(x + 5, y + 17, 3, 5 + legOffset);
  ctx.fillRect(x + 12, y + 17, 3, 5 - legOffset);
  // 靴子
  ctx.fillStyle = c.boot;
  ctx.fillRect(x + 5, y + 22 + legOffset, 3, 1);
  ctx.fillRect(x + 12, y + 22 - legOffset, 3, 1);

  // 背包（左侧）
  ctx.fillStyle = '#7a5a3a';
  ctx.fillRect(x + 1, y + 10, 2, 5);
  ctx.fillStyle = '#5a3a2a';
  ctx.fillRect(x + 1, y + 14, 2, 1);
}

// ============================================================
//  像素绘制：怪物
// ============================================================
function drawMonster(m) {
  const x = Math.floor(m.x - m.w / 2);
  const y = Math.floor(m.y - m.h / 2);
  const t = m.animTime;

  const col = m.type.color;
  const flash = m.hurtFlash > 0;

  ctx.save();
  if (flash) ctx.filter = 'brightness(3)';

  switch (m.typeKey) {
    case 'worm': drawWorm(x, y, t, col); break;
    case 'tentacle': drawTentacle(x, y, t, col); break;
    case 'walker': drawWalker(x, y, t, col); break;
    case 'eye': drawEye(x, y, t, col); break;
    case 'slime': drawSlime(x, y, t, col); break;
  }
  ctx.restore();

  // 血条
  if (m.hp < m.maxHp) {
    const bw = m.w;
    const bx = Math.floor(m.x - bw / 2);
    const by = Math.floor(m.y - m.h / 2 - 6);
    ctx.fillStyle = '#1a0a0a';
    ctx.fillRect(bx, by, bw, 3);
    ctx.fillStyle = '#c43a3a';
    ctx.fillRect(bx, by, Math.floor(bw * (m.hp / m.maxHp)), 3);
  }
}

function drawWorm(x, y, t, col) {
  // 蠕动的蠕虫：多节身体
  const segs = 5;
  const wave = Math.sin(t * 4) * 2;
  for (let i = segs - 1; i >= 0; i--) {
    const sx = x + i * 4;
    const sy = y + 4 + Math.sin(t * 4 + i * 0.8) * 2;
    const sz = 5 - i * 0.3;
    ctx.fillStyle = col[Math.min(i, col.length - 1)];
    ctx.fillRect(Math.floor(sx), Math.floor(sy), Math.ceil(sz), Math.ceil(sz + 1));
    // 高光
    if (i === 0) {
      ctx.fillStyle = col[0];
      ctx.fillRect(Math.floor(sx), Math.floor(sy - 1), 5, 2);
      // 眼
      ctx.fillStyle = '#fff';
      ctx.fillRect(Math.floor(sx + 2), Math.floor(sy + 1), 1, 1);
    }
  }
  // 尾须
  ctx.fillStyle = col[2];
  const tailY = y + 4 + Math.sin(t * 4 + segs * 0.8) * 2;
  ctx.fillRect(Math.floor(x + segs * 4), Math.floor(tailY + 1), 2, 1);
  ctx.fillRect(Math.floor(x + segs * 4 + 1), Math.floor(tailY), 1, 2);
}

function drawTentacle(x, y, t, col) {
  // 触手怪：底部尖，上方多条触手挥舞
  const cx = x + 13, cy = y + 13;
  // 主体（椭球）
  ctx.fillStyle = col[1];
  for (let py = 0; py < 16; py++) {
    const w = 10 - Math.abs(py - 8) * 0.6;
    ctx.fillRect(Math.floor(cx - w), Math.floor(y + py + 5), Math.ceil(w * 2), 1);
  }
  // 高光
  ctx.fillStyle = col[0];
  ctx.fillRect(cx - 4, y + 7, 3, 2);

  // 触手（4条）
  for (let i = 0; i < 4; i++) {
    const baseA = (i / 4) * TAU + t * 0.5;
    const wave = Math.sin(t * 3 + i) * 3;
    ctx.fillStyle = col[2];
    for (let j = 0; j < 6; j++) {
      const a = baseA + j * 0.3;
      const r = 6 + j * 2 + wave * 0.3;
      const tx = cx + Math.cos(a) * r;
      const ty = cy + Math.sin(a) * r * 0.7;
      ctx.fillRect(Math.floor(tx), Math.floor(ty), 2, 2);
    }
    // 触手末端吸盘
    const endA = baseA + 5 * 0.3;
    const endR = 6 + 10 + wave * 0.3;
    ctx.fillStyle = col[3];
    ctx.fillRect(
      Math.floor(cx + Math.cos(endA) * endR),
      Math.floor(cy + Math.sin(endA) * endR * 0.7),
      2, 2
    );
  }
}

function drawWalker(x, y, t, col) {
  // 深渊行者：瘦长人形，拖曳行走
  const f = Math.floor(t * 3) % 2;
  const sway = f === 0 ? -1 : 1;

  // 身体（长袍）
  ctx.fillStyle = col[1];
  ctx.fillRect(x + 6, y + 8, 12, 18);
  ctx.fillStyle = col[0];
  ctx.fillRect(x + 8, y + 8, 3, 4);

  // 头（兜帽，没脸）
  ctx.fillStyle = col[2];
  ctx.fillRect(x + 7, y + 2, 10, 6);
  ctx.fillStyle = col[3];
  ctx.fillRect(x + 9, y + 5, 6, 2); // 黑暗的脸
  // 一点幽光
  ctx.fillStyle = '#6b8a6f';
  ctx.fillRect(x + 10, y + 5, 1, 1);
  ctx.fillRect(x + 13, y + 5, 1, 1);

  // 手臂（长且下垂）
  ctx.fillStyle = col[1];
  ctx.fillRect(x + 2, y + 10 + sway, 4, 10);
  ctx.fillRect(x + 18, y + 10 - sway, 4, 10);
  ctx.fillStyle = col[2];
  ctx.fillRect(x + 2, y + 19 + sway, 4, 2);
  ctx.fillRect(x + 18, y + 19 - sway, 4, 2);

  // 袍脚
  ctx.fillStyle = col[2];
  ctx.fillRect(x + 5, y + 26, 14, 3);
  ctx.fillStyle = col[3];
  ctx.fillRect(x + 5, y + 28, 14, 1);
}

function drawEye(x, y, t, col) {
  // 浮游眼：眼球 + 飘动
  const bob = Math.sin(t * 3) * 2;
  const cx = x + 9, cy = y + 9 + bob;

  // 眼白
  ctx.fillStyle = col[0];
  ctx.fillRect(cx - 6, cy - 5, 12, 10);
  ctx.fillRect(cx - 7, cy - 3, 14, 6);
  ctx.fillRect(cx - 6, cy + 4, 12, 1);

  // 眼睑阴影
  ctx.fillStyle = col[2];
  ctx.fillRect(cx - 6, cy - 5, 12, 2);
  ctx.fillRect(cx - 6, cy + 3, 12, 2);

  // 瞳孔（红）
  const pupilX = cx + Math.sin(t * 2) * 2;
  ctx.fillStyle = '#c43a3a';
  ctx.fillRect(pupilX - 2, cy - 2, 4, 4);
  ctx.fillStyle = '#8a1a1a';
  ctx.fillRect(pupilX - 1, cy - 1, 2, 2);

  // 血丝
  ctx.fillStyle = col[1];
  ctx.fillRect(cx - 5, cy, 2, 1);
  ctx.fillRect(cx + 3, cy - 1, 2, 1);
}

function drawSlime(x, y, t, col) {
  // 深渊粘液：弹跳的胶状生物
  const squash = 1 + Math.sin(t * 4) * 0.15;
  const bw = 20, bh = 14 * squash;
  const bx = x + 2, by = y + (16 - bh);

  ctx.fillStyle = col[2];
  ctx.fillRect(bx + 1, by + bh - 2, bw - 2, 2);
  ctx.fillStyle = col[1];
  ctx.fillRect(bx, by + 2, bw, bh - 3);
  ctx.fillRect(bx + 1, by + 1, bw - 2, 1);
  ctx.fillStyle = col[0];
  ctx.fillRect(bx + 2, by + 2, bw - 6, 2);
  // 高光
  ctx.fillStyle = '#a0e0d0';
  ctx.fillRect(bx + 3, by + 3, 2, 1);
  ctx.fillRect(bx + 4, by + 4, 1, 1);

  // 眼睛
  ctx.fillStyle = '#fff';
  ctx.fillRect(bx + 5, by + 5, 2, 2);
  ctx.fillRect(bx + 12, by + 5, 2, 2);
  ctx.fillStyle = '#1a1a1a';
  ctx.fillRect(bx + 6, by + 6, 1, 1);
  ctx.fillRect(bx + 13, by + 6, 1, 1);
}

// ============================================================
//  像素绘制：武器 / 投射物
// ============================================================
function drawOrbitingWeapon(orb) {
  const x = player.x + Math.cos(orb.angle) * orb.radius;
  const y = player.y + Math.sin(orb.angle) * orb.radius;
  // 镰刀：像素刀片
  ctx.save();
  ctx.translate(Math.floor(x), Math.floor(y));
  ctx.rotate(orb.angle + Math.PI / 2);
  // 柄
  ctx.fillStyle = '#6b4a2a';
  ctx.fillRect(-1, -6, 2, 12);
  // 刀身
  ctx.fillStyle = '#c0c0c8';
  ctx.fillRect(-4, -8, 8, 2);
  ctx.fillRect(-5, -7, 2, 3);
  ctx.fillStyle = '#888';
  ctx.fillRect(2, -7, 3, 2);
  ctx.fillStyle = '#e8e8f0';
  ctx.fillRect(-4, -8, 4, 1);
  ctx.restore();

  // 轨迹残影
  ctx.fillStyle = 'rgba(200,200,220,0.15)';
  const trailAngle = orb.angle - 0.3;
  const tx = player.x + Math.cos(trailAngle) * orb.radius;
  const ty = player.y + Math.sin(trailAngle) * orb.radius;
  ctx.fillRect(Math.floor(tx) - 2, Math.floor(ty) - 2, 4, 4);
}

function drawProjectile(p) {
  // 发光投射物
  ctx.fillStyle = '#8fe07a';
  ctx.fillRect(Math.floor(p.x) - 2, Math.floor(p.y) - 2, 5, 5);
  ctx.fillStyle = '#c8ffb0';
  ctx.fillRect(Math.floor(p.x) - 1, Math.floor(p.y) - 1, 3, 3);
  ctx.fillStyle = '#fff';
  ctx.fillRect(Math.floor(p.x), Math.floor(p.y), 1, 1);
  // 拖尾
  ctx.fillStyle = 'rgba(143, 224, 122, 0.4)';
  ctx.fillRect(Math.floor(p.x - p.vx * 0.02), Math.floor(p.y - p.vy * 0.02), 3, 3);
}

// ============================================================
//  像素绘制：掉落物
// ============================================================
function drawDrop(d) {
  const bob = Math.sin(d.bobTime * 3) * 2;
  const x = Math.floor(d.x), y = Math.floor(d.y + bob);
  if (d.type === 'gold') {
    // 金币
    ctx.fillStyle = '#d4a84a';
    ctx.fillRect(x - 3, y - 3, 6, 6);
    ctx.fillStyle = '#f0c86a';
    ctx.fillRect(x - 2, y - 3, 3, 2);
    ctx.fillRect(x - 3, y - 2, 2, 2);
    ctx.fillStyle = '#a8782a';
    ctx.fillRect(x - 3, y + 2, 6, 1);
    // 光泽
    ctx.fillStyle = '#fff0b0';
    ctx.fillRect(x - 1, y - 2, 1, 1);
  } else if (d.type === 'exp') {
    // 经验宝石（幽绿）
    ctx.fillStyle = '#6fd36f';
    ctx.fillRect(x - 2, y - 3, 4, 6);
    ctx.fillRect(x - 3, y - 2, 6, 4);
    ctx.fillStyle = '#a0e8a0';
    ctx.fillRect(x - 1, y - 2, 2, 2);
    ctx.fillStyle = '#3e9a4a';
    ctx.fillRect(x - 2, y + 2, 4, 1);
    // 光点
    ctx.fillStyle = '#fff';
    ctx.fillRect(x, y - 1, 1, 1);
  } else if (d.type === 'heart') {
    ctx.fillStyle = '#e04a4a';
    ctx.fillRect(x - 3, y - 2, 6, 4);
    ctx.fillRect(x - 2, y - 3, 2, 1);
    ctx.fillRect(x + 0, y - 3, 2, 1);
    ctx.fillRect(x - 2, y + 2, 4, 1);
    ctx.fillRect(x - 1, y + 3, 2, 1);
  }
}

// ============================================================
//  地面纹理
// ============================================================
// 预生成地砖纹理
const tileCanvas = document.createElement('canvas');
const tileCtx = tileCanvas.getContext('2d');
function generateTile() {
  const s = 64;
  tileCanvas.width = s;
  tileCanvas.height = s;
  const tc = tileCtx;
  tc.imageSmoothingEnabled = false;

  // 基础石色
  tc.fillStyle = '#2a2e26';
  tc.fillRect(0, 0, s, s);

  // 石块缝隙
  tc.fillStyle = '#1f231a';
  // 横向缝
  for (let y = 0; y < s; y += 16) {
    tc.fillRect(0, y, s, 1);
    // 纵向偏移缝
    const offset = (y / 16) % 2 === 0 ? 0 : 20;
    for (let x = offset; x < s; x += 32) {
      tc.fillRect(x, y, 1, 16);
    }
  }

  // 颗粒噪点
  for (let i = 0; i < 80; i++) {
    const px = randi(0, s);
    const py = randi(0, s);
    const shade = Math.random();
    if (shade < 0.4) tc.fillStyle = '#3a3e30';
    else if (shade < 0.7) tc.fillStyle = '#252820';
    else tc.fillStyle = '#1a1c16';
    tc.fillRect(px, py, 1, 1);
  }

  // 苔藓斑
  for (let i = 0; i < 6; i++) {
    const px = randi(0, s);
    const py = randi(0, s);
    tc.fillStyle = '#3e5a3a';
    tc.fillRect(px, py, 2, 1);
    tc.fillRect(px + 1, py + 1, 1, 1);
    tc.fillStyle = '#4a6b42';
    tc.fillRect(px + 1, py, 1, 1);
  }
}
generateTile();

function drawGround() {
  const tileSize = 64;
  const startX = Math.floor(camera.x / tileSize) * tileSize;
  const startY = Math.floor(camera.y / tileSize) * tileSize;
  const endX = camera.x + W + tileSize;
  const endY = camera.y + H + tileSize;

  for (let x = startX; x < endX; x += tileSize) {
    for (let y = startY; y < endY; y += tileSize) {
      ctx.drawImage(tileCanvas, x - camera.x, y - camera.y);
    }
  }
}

// ============================================================
//  雾气 / 符文
// ============================================================
function updateFog(dt) {
  for (const f of fogParticles) {
    f.x += f.vx * dt;
    f.y += f.vy * dt;
    f.phase += dt * 0.5;
    if (f.x < -100) f.x = WORLD.w + 100;
    if (f.x > WORLD.w + 100) f.x = -100;
    if (f.y < -100) f.y = WORLD.h + 100;
    if (f.y > WORLD.h + 100) f.y = -100;
  }
}

function drawFog() {
  for (const f of fogParticles) {
    const sx = f.x - camera.x;
    const sy = f.y - camera.y;
    if (sx < -f.size || sx > W + f.size || sy < -f.size || sy > H + f.size) continue;

    const pulse = 0.5 + 0.5 * Math.sin(f.phase);
    const a = f.alpha * (0.7 + pulse * 0.3);

    ctx.fillStyle = `rgba(120, 150, 130, ${a})`;
    const steps = 6;
    for (let i = 0; i < steps; i++) {
      const r = f.size * (1 - i / steps);
      const oy = i * 2;
      ctx.fillRect(Math.floor(sx - r), Math.floor(sy - r / 2 + oy), Math.ceil(r * 2), 2);
    }
  }
}

function updateRunes(dt) {
  for (const r of runeLights) {
    r.phase += dt * r.speed;
  }
}

function drawRunes() {
  for (const r of runeLights) {
    const pulse = 0.3 + 0.7 * Math.abs(Math.sin(r.phase));
    const sx = r.x - camera.x;
    const sy = r.y - camera.y;
    if (sx < -20 || sx > W + 20 || sy < -20 || sy > H + 20) continue;

    const a = pulse * 0.5;
    // 符文光晕
    ctx.fillStyle = `rgba(107, 138, 111, ${a * 0.3})`;
    ctx.fillRect(Math.floor(sx - r.size), Math.floor(sy - r.size / 2), r.size * 2, r.size);
    // 符文本体（简化像素符号）
    ctx.fillStyle = `rgba(143, 224, 122, ${a})`;
    const s = Math.floor(r.size / 3);
    ctx.fillRect(Math.floor(sx - s), Math.floor(sy - 1), s * 2, 1);
    ctx.fillRect(Math.floor(sx - 1), Math.floor(sy - s), 1, s * 2);
    ctx.fillRect(Math.floor(sx - s / 2), Math.floor(sy + s - 2), s, 1);
  }
}

function updateSilhouettes(dt) {
  for (const s of silhouettes) {
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    s.changeTimer -= dt;
    if (s.changeTimer <= 0) {
      s.changeTimer = rand(4, 10);
      s.targetAlpha = s.targetAlpha > 0 ? 0 : rand(0.04, 0.08);
    }
    s.alpha += (s.targetAlpha - s.alpha) * dt * 0.5;

    if (s.x < -100) s.x = WORLD.w + 100;
    if (s.x > WORLD.w + 100) s.x = -100;
    if (s.y < -100) s.y = WORLD.h + 100;
    if (s.y > WORLD.h + 100) s.y = -100;
  }
}

function drawSilhouettes() {
  for (const s of silhouettes) {
    const sx = s.x - camera.x;
    const sy = s.y - camera.y;
    if (sx < -s.size || sx > W + s.size || sy < -s.size || sy > H + s.size) continue;
    if (s.alpha < 0.01) continue;

    // 不可名状剪影：一堆不规则像素堆
    ctx.fillStyle = `rgba(20, 15, 30, ${s.alpha})`;
    const w = s.size, h = s.size * 0.6;
    const baseX = Math.floor(sx - w / 2);
    const baseY = Math.floor(sy - h / 2);
    for (let py = 0; py < h; py += 2) {
      const wav = Math.sin(py * 0.3 + s.x * 0.01) * w * 0.15;
      const lineW = w * (0.5 + 0.5 * Math.sin(py * 0.2)) + wav;
      ctx.fillRect(
        Math.floor(baseX + (w - lineW) / 2),
        baseY + py,
        Math.ceil(lineW),
        2
      );
    }
    // 顶部触手状突起
    for (let i = 0; i < 4; i++) {
      const tx = baseX + w * (0.2 + i * 0.2);
      const th = h * 0.3 + Math.sin(s.x * 0.02 + i) * 4;
      ctx.fillRect(Math.floor(tx), Math.floor(baseY - th), 2, Math.ceil(th));
    }
  }
}

// ============================================================
//  粒子绘制
// ============================================================
function drawParticles() {
  for (const p of particles) {
    const a = p.life / p.maxLife;
    ctx.globalAlpha = a;
    ctx.fillStyle = p.color;
    ctx.fillRect(Math.floor(p.x - camera.x - p.size / 2), Math.floor(p.y - camera.y - p.size / 2), p.size, p.size);
  }
  ctx.globalAlpha = 1;
}

// ============================================================
//  更新逻辑
// ============================================================
function update(dt) {
  renderDt = dt;
  updatePlayer(dt);
  updateMonsters(dt);
  updateProjectiles(dt);
  updateDrops(dt);
  updateParticles(dt);
  updateFog(dt);
  updateRunes(dt);
  updateSilhouettes(dt);
  updateCamera(dt);
  updateWave(dt);
  updateUI(dt);

  // 屏幕震动衰减
  if (gameState.screenShake > 0) {
    gameState.screenShake = Math.max(0, gameState.screenShake - dt * 20);
  }
  if (gameState.levelupFlash > 0) {
    gameState.levelupFlash = Math.max(0, gameState.levelupFlash - dt * 2);
  }
}

function updatePlayer(dt) {
  let dx = 0, dy = 0;
  if (keys['w'] || keys['arrowup']) dy -= 1;
  if (keys['s'] || keys['arrowdown']) dy += 1;
  if (keys['a'] || keys['arrowleft']) dx -= 1;
  if (keys['d'] || keys['arrowright']) dx += 1;

  if (dx !== 0 || dy !== 0) {
    const len = Math.hypot(dx, dy);
    dx /= len; dy /= len;
    player.x += dx * player.speed * dt;
    player.y += dy * player.speed * dt;
    player.walkTimer += dt;
    if (player.walkTimer > 0.15) {
      player.walkTimer = 0;
      player.walkFrame++;
    }
    if (dx > 0.1) player.facing = 1;
    else if (dx < -0.1) player.facing = -1;
  } else {
    player.walkFrame = 0;
  }

  player.x = clamp(player.x, 20, WORLD.w - 20);
  player.y = clamp(player.y, 20, WORLD.h - 20);

  // 无敌帧
  if (player.invuln > 0) player.invuln -= dt;

  // 环绕武器
  for (const orb of player.orbiting) {
    orb.angle += orb.speed * dt;
    if (orb.hitCooldown > 0) orb.hitCooldown -= dt;

    // 武器与怪物碰撞
    const wx = player.x + Math.cos(orb.angle) * orb.radius;
    const wy = player.y + Math.sin(orb.angle) * orb.radius;
    if (orb.hitCooldown <= 0) {
      for (const m of monsters) {
        if (Math.hypot(wx - m.x, wy - m.y) < m.w / 2 + orb.size) {
          damageMonster(m, orb.damage, Math.atan2(wy - m.y, wx - m.x));
          orb.hitCooldown = 0.3;
          break;
        }
      }
    }
  }

  // 自动射击：找最近怪物
  player.attackCooldown -= dt;
  if (player.attackCooldown <= 0 && monsters.length > 0) {
    let nearest = null, nd = 9999;
    for (const m of monsters) {
      const d = dist(player, m);
      if (d < nd && d < 280) { nd = d; nearest = m; }
    }
    if (nearest) {
      const ang = Math.atan2(nearest.y - player.y, nearest.x - player.x);
      shootProjectile(ang);
      player.attackCooldown = 0.8;
    }
  }
}

function updateMonsters(dt) {
  for (let i = monsters.length - 1; i >= 0; i--) {
    const m = monsters[i];
    m.animTime += dt;
    if (m.hurtFlash > 0) m.hurtFlash -= dt;

    // 向玩家移动
    const ang = Math.atan2(player.y - m.y, player.x - m.x);
    m.x += Math.cos(ang) * m.speed * dt;
    m.y += Math.sin(ang) * m.speed * dt;

    // 击退
    m.x += m.knockback.x * dt;
    m.y += m.knockback.y * dt;
    m.knockback.x *= 0.9;
    m.knockback.y *= 0.9;

    // 碰到玩家
    if (Math.hypot(m.x - player.x, m.y - player.y) < m.w / 2 + 10) {
      hurtPlayer(m.damage);
      // 击退怪物
      m.knockback.x = Math.cos(ang) * 200;
      m.knockback.y = Math.sin(ang) * 200;
    }
  }
}

function updateProjectiles(dt) {
  for (let i = projectiles.length - 1; i >= 0; i--) {
    const p = projectiles[i];
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.life -= dt;
    if (p.life <= 0) { projectiles.splice(i, 1); continue; }

    // 碰怪物
    let hit = false;
    for (const m of monsters) {
      if (Math.hypot(p.x - m.x, p.y - m.y) < m.w / 2 + p.size) {
        damageMonster(m, p.damage, Math.atan2(p.vy, p.vx));
        hit = true;
        break;
      }
    }
    if (hit) { projectiles.splice(i, 1); continue; }
  }
}

function damageMonster(m, dmg, angle) {
  m.hp -= dmg;
  m.hurtFlash = 0.08;
  m.knockback.x += Math.cos(angle) * 100;
  m.knockback.y += Math.sin(angle) * 100;

  // 伤害数字粒子
  spawnParticle(m.x + rand(-5, 5), m.y - 10, {
    vx: rand(-20, 20), vy: -40,
    life: 0.6, size: 1,
    color: '#ffe04a',
    gravity: 80,
  });

  if (m.hp <= 0) {
    killMonster(m);
  }
}

function killMonster(m) {
  const idx = monsters.indexOf(m);
  if (idx === -1) return;
  monsters.splice(idx, 1);

  // 爆炸粒子
  explosion(m.x, m.y, m.type.color[1], 10);
  explosion(m.x, m.y, m.type.color[0], 5);

  // 掉落
  if (Math.random() < 0.85) {
    spawnDrop(m.x, m.y, 'gold', m.gold);
  }
  // 经验宝石
  for (let i = 0; i < Math.ceil(m.exp / 2); i++) {
    spawnDrop(m.x + rand(-5, 5), m.y + rand(-5, 5), 'exp', 2);
  }
  // 小概率掉心
  if (Math.random() < 0.04) {
    spawnDrop(m.x, m.y, 'heart', 20);
  }
}

function hurtPlayer(dmg) {
  if (player.invuln > 0) return;
  player.invuln = 0.6;

  // 先扣护甲
  if (player.shield > 0) {
    const absorbed = Math.min(player.shield, dmg);
    player.shield -= absorbed;
    dmg -= absorbed;
  }
  if (dmg > 0) {
    player.hp = Math.max(0, player.hp - dmg);
  }

  gameState.screenShake = 5;
  explosion(player.x, player.y, '#c43a3a', 6);

  // UI 反馈
  flashBar('hp');
  updateHpText();
  flashBar('shield');
  updateShieldText();

  if (player.hp <= 0) {
    // 简单重生
    player.hp = player.maxHp;
    player.shield = 0;
    player.x = WORLD.w / 2;
    player.y = WORLD.h / 2;
    player.gold = Math.floor(player.gold * 0.5);
    updateGoldUI();
  }
}

function updateDrops(dt) {
  for (let i = drops.length - 1; i >= 0; i--) {
    const d = drops[i];
    d.bobTime += dt;
    d.life -= dt;
    if (d.life <= 0) { drops.splice(i, 1); continue; }

    // 物理
    d.vy += 60 * dt; // 轻微重力
    d.x += d.vx * dt;
    d.y += d.vy * dt;
    d.vx *= 0.95;
    d.vy *= 0.95;

    // 地面约束
    if (d.y > player.y + 40) { d.y = player.y + 40; d.vy *= -0.3; }

    // 玩家拾取范围
    const pd = dist(d, player);
    const pickupRange = 50;
    const magnetRange = 100;

    if (pd < magnetRange) {
      const ang = Math.atan2(player.y - d.y, player.x - d.x);
      const sp = 200 * (1 - pd / magnetRange);
      d.x += Math.cos(ang) * sp * dt;
      d.y += Math.sin(ang) * sp * dt;
    }

    if (pd < pickupRange) {
      // 拾取
      if (d.type === 'gold') {
        player.gold += d.value;
        showFloatText('+' + d.value, d.x, d.y, '#ffe04a');
        updateGoldUI();
      } else if (d.type === 'exp') {
        gainExp(d.value);
      } else if (d.type === 'heart') {
        player.hp = Math.min(player.maxHp, player.hp + d.value);
        showFloatText('+' + d.value, d.x, d.y, '#ff6a6a');
        flashBar('hp');
        updateHpText();
      }
      drops.splice(i, 1);
    }
  }
}

function gainExp(amount) {
  player.exp += amount;
  updateExpUI();
  flashExp();

  while (player.exp >= player.expToNext) {
    player.exp -= player.expToNext;
    player.level++;
    player.expToNext = Math.floor(player.expToNext * 1.6);
    // 升级奖励
    player.maxHp += 10;
    player.hp = player.maxHp;
    // 加一把环绕武器（最多6）
    if (player.orbiting.length < 6) {
      const n = player.orbiting.length;
      player.orbiting.push({
        angle: (n / (n + 1)) * TAU,
        radius: 48 + n * 3,
        speed: 2.2,
        damage: 15,
        size: 10,
        hitCooldown: 0,
      });
    }
    // 升级特效
    gameState.levelupFlash = 1;
    explosion(player.x, player.y, '#8fe07a', 30);
    explosion(player.x, player.y, '#fff', 15);
    gameState.screenShake = 3;
    updateLevelUI();
    updateExpUI();
    updateHpText();
  }
}

function updateParticles(dt) {
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i];
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.vy += p.gravity * dt;
    p.vx *= 0.98;
    p.vy *= 0.98;
    p.life -= dt;
    if (p.life <= 0) particles.splice(i, 1);
  }
}

function updateCamera(dt) {
  // 缓动跟随玩家
  const targetX = player.x - W / 2;
  const targetY = player.y - H / 2;
  camera.x += (targetX - camera.x) * Math.min(1, dt * 5);
  camera.y += (targetY - camera.y) * Math.min(1, dt * 5);

  // 屏幕震动
  if (gameState.screenShake > 0) {
    camera.x += rand(-gameState.screenShake, gameState.screenShake);
    camera.y += rand(-gameState.screenShake, gameState.screenShake);
  }
}

function updateWave(dt) {
  gameState.waveTimer -= dt;

  // 生成怪物
  gameState.spawnTimer -= dt;
  const maxMonsters = 15 + gameState.wave * 5;
  if (gameState.spawnTimer <= 0 && monsters.length < maxMonsters) {
    const toSpawn = Math.min(3, maxMonsters - monsters.length);
    for (let i = 0; i < toSpawn; i++) spawnMonster();
    gameState.spawnTimer = gameState.spawnInterval;
  }

  if (gameState.waveTimer <= 0) {
    // 下一波
    gameState.wave++;
    gameState.waveTimer = 60;
    gameState.spawnInterval = Math.max(0.4, 1.5 - gameState.wave * 0.1);
    gameState.screenShake = 8;
    gameState.waveTransition = 1;
    explosion(player.x, player.y, '#6b4a8f', 25);
    updateWaveUI();
    // 屏幕震动CSS
    document.getElementById('game-wrap').classList.add('shake');
    setTimeout(() => {
      document.getElementById('game-wrap').classList.remove('shake');
    }, 350);
  }
}

// ============================================================
//  UI 更新
// ============================================================
function updateHpText() {
  document.getElementById('hpText').textContent = Math.floor(player.hp) + '/' + player.maxHp;
  document.getElementById('hpFill').style.width = (player.hp / player.maxHp * 100) + '%';
}
function updateShieldText() {
  document.getElementById('shieldText').textContent = Math.floor(player.shield) + '/' + player.maxShield;
  document.getElementById('shieldFill').style.width = player.maxShield > 0 ? (player.shield / player.maxShield * 100) + '%' : '0%';
}
function updateGoldUI() {
  const el = document.getElementById('goldNum');
  el.textContent = player.gold.toLocaleString();
  el.classList.remove('bump');
  void el.offsetWidth;
  el.classList.add('bump');
}
function updateLevelUI() {
  document.getElementById('levelBadge').textContent = 'Lv.' + player.level;
}
function updateExpUI() {
  document.getElementById('expText').textContent =
    '等级 ' + player.level + '\u3000经验 ' + player.exp + '/' + player.expToNext;
  document.getElementById('expFill').style.width = (player.exp / player.expToNext * 100) + '%';
}
function updateWaveUI() {
  document.getElementById('waveLabel').textContent = '第 ' + gameState.wave + ' 波';
}

function flashBar(which) {
  const el = document.getElementById(which + 'Fill');
  el.classList.remove('bar-flash');
  void el.offsetWidth;
  el.classList.add('bar-flash');
}
function flashExp() {
  const el = document.getElementById('expFill');
  el.classList.remove('bar-flash');
  void el.offsetWidth;
  el.classList.add('bar-flash');
}

function updateUI(dt) {
  // 倒计时
  const t = Math.max(0, Math.ceil(gameState.waveTimer));
  const timerEl = document.getElementById('waveTimer');
  timerEl.textContent = t + 's';
  if (t <= 10) {
    timerEl.classList.add('warn');
  } else {
    timerEl.classList.remove('warn');
  }
}

// 飘字
function showFloatText(text, wx, wy, color) {
  const el = document.createElement('div');
  el.className = 'float-text';
  el.textContent = text;
  el.style.color = color;
  el.style.left = (wx - camera.x) + 'px';
  el.style.top = (wy - camera.y) + 'px';
  document.getElementById('game-wrap').appendChild(el);
  setTimeout(() => el.remove(), 1000);
}

// ============================================================
//  像素图标绘制（UI 图标）
// ============================================================
function drawHeartIcon() {
  const c = document.getElementById('heartIcon');
  const cx = c.getContext('2d');
  cx.imageSmoothingEnabled = false;
  cx.clearRect(0, 0, 20, 20);
  // 心形
  cx.fillStyle = '#c43a3a';
  cx.fillRect(3, 4, 4, 4);
  cx.fillRect(13, 4, 4, 4);
  cx.fillRect(2, 6, 16, 5);
  cx.fillRect(4, 11, 12, 2);
  cx.fillRect(6, 13, 8, 2);
  cx.fillRect(8, 15, 4, 1);
  // 高光
  cx.fillStyle = '#e06a6a';
  cx.fillRect(4, 5, 2, 2);
  cx.fillRect(3, 7, 1, 2);
  // 暗部
  cx.fillStyle = '#8a2222';
  cx.fillRect(13, 10, 3, 1);
  cx.fillRect(11, 12, 3, 1);
}
function drawShieldIcon() {
  const c = document.getElementById('shieldIcon');
  const cx = c.getContext('2d');
  cx.imageSmoothingEnabled = false;
  cx.clearRect(0, 0, 20, 20);
  cx.fillStyle = '#6b4a8f';
  cx.fillRect(4, 2, 12, 2);
  cx.fillRect(3, 4, 14, 8);
  cx.fillRect(4, 12, 12, 3);
  cx.fillRect(6, 15, 8, 2);
  cx.fillRect(8, 17, 4, 1);
  // 高光
  cx.fillStyle = '#8a6ab0';
  cx.fillRect(5, 3, 3, 1);
  cx.fillRect(4, 5, 2, 3);
  // 暗部
  cx.fillStyle = '#3e2a5a';
  cx.fillRect(12, 11, 4, 1);
  cx.fillRect(10, 14, 3, 1);
  // 中心符文
  cx.fillStyle = '#b090d0';
  cx.fillRect(9, 6, 2, 5);
  cx.fillRect(7, 8, 6, 1);
}
function drawCoinIcon() {
  const c = document.getElementById('coinIcon');
  const cx = c.getContext('2d');
  cx.imageSmoothingEnabled = false;
  cx.clearRect(0, 0, 16, 16);
  cx.fillStyle = '#d4a84a';
  cx.fillRect(3, 2, 10, 12);
  cx.fillRect(2, 4, 12, 8);
  cx.fillStyle = '#f0c86a';
  cx.fillRect(4, 3, 4, 2);
  cx.fillRect(3, 5, 2, 3);
  cx.fillStyle = '#a8782a';
  cx.fillRect(3, 12, 10, 1);
  cx.fillRect(11, 6, 2, 5);
  // 字
  cx.fillStyle = '#fff0b0';
  cx.fillRect(7, 5, 2, 6);
  cx.fillRect(6, 7, 4, 1);
}
function drawBankIcon() {
  const c = document.getElementById('bankIcon');
  const cx = c.getContext('2d');
  cx.imageSmoothingEnabled = false;
  cx.clearRect(0, 0, 16, 16);
  // 金库/箱子
  cx.fillStyle = '#6b4a2a';
  cx.fillRect(2, 4, 12, 10);
  cx.fillStyle = '#8a6a3a';
  cx.fillRect(2, 4, 12, 2);
  cx.fillStyle = '#4a3020';
  cx.fillRect(2, 12, 12, 2);
  // 锁
  cx.fillStyle = '#d4a84a';
  cx.fillRect(7, 7, 2, 4);
  cx.fillRect(6, 8, 4, 2);
  cx.fillStyle = '#f0c86a';
  cx.fillRect(7, 7, 1, 1);
  // 盖子顶部
  cx.fillStyle = '#5a3a20';
  cx.fillRect(1, 4, 1, 1);
  cx.fillRect(14, 4, 1, 1);
}
drawHeartIcon();
drawShieldIcon();
drawCoinIcon();
drawBankIcon();

// ============================================================
//  主循环
// ============================================================
let lastTime = performance.now();
function loop(now) {
  const dt = Math.min(0.05, (now - lastTime) / 1000);
  lastTime = now;

  update(dt);
  render();

  requestAnimationFrame(loop);
}

let renderDt = 1 / 60;
function render() {
  ctx.clearRect(0, 0, W, H);

  // 地面
  drawGround();

  // 符文（地面层）
  drawRunes();

  // 雾气（地面层，较淡）
  drawFog();

  // 不可名状剪影（中景）
  drawSilhouettes();

  // 掉落物
  for (const d of drops) drawDrop(d);

  // 怪物（按 y 排序做伪深度）
  const sorted = [...monsters].sort((a, b) => a.y - b.y);
  for (const m of sorted) {
    ctx.save();
    ctx.translate(-camera.x, -camera.y);
    drawMonster(m);
    ctx.restore();
  }

  // 玩家
  ctx.save();
  ctx.translate(-camera.x, -camera.y);
  drawPlayer(player.x, player.y);
  ctx.restore();

  // 环绕武器（在玩家上方）
  ctx.save();
  ctx.translate(-camera.x, -camera.y);
  for (const orb of player.orbiting) drawOrbitingWeapon(orb);
  ctx.restore();

  // 投射物
  ctx.save();
  ctx.translate(-camera.x, -camera.y);
  for (const p of projectiles) drawProjectile(p);
  ctx.restore();

  // 粒子
  drawParticles();

  // 升级全屏闪光
  if (gameState.levelupFlash > 0) {
    ctx.fillStyle = `rgba(200, 255, 180, ${gameState.levelupFlash * 0.3})`;
    ctx.fillRect(0, 0, W, H);
  }
}

// 由于雾气/符文/剪影在 render 中调用但依赖 dt，用近似值
// 实际 update 中已更新它们的状态

// 古神之眼随机眨眼
setInterval(() => {
  const eyes = ['eyeTL', 'eyeTR', 'eyeBL', 'eyeBR'];
  if (Math.random() < 0.4) {
    const eye = document.getElementById(eyes[randi(0, eyes.length)]);
    eye.classList.remove('blink');
    void eye.offsetWidth;
    eye.classList.add('blink');
  }
}, 2500);

// 启动
updateHpText();
updateShieldText();
updateGoldUI();
updateLevelUI();
updateExpUI();
updateWaveUI();
requestAnimationFrame(loop);

// 宣告可升级
function announceUpgrade() {
  try {
    window.parent.postMessage({ type: 'miaoda:upgrade:available', kind: 'interactive-prototype' }, '*');
  } catch(e) {}
}
announceUpgrade();
if (document.readyState !== 'complete') window.addEventListener('load', announceUpgrade, { once: true });
