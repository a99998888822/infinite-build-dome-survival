const React = window.React;
const ReactDOM = window.ReactDOM;
const { useState, useEffect, useRef, useCallback } = React;

// ============================================
// 像素风 SVG Icon 组件
// ============================================

// 军用步枪
function IconRifle({ size = 36 }) {
  const s = size / 24;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={{ imageRendering: 'pixelated' }}>
      {/* 枪托 */}
      <rect x="1" y="9" width="5" height="6" fill="#5a4a2a" />
      <rect x="1" y="9" width="5" height="2" fill="#7a6540" />
      {/* 机匣 */}
      <rect x="6" y="8" width="6" height="8" fill="#3d3d3d" />
      <rect x="6" y="8" width="6" height="2" fill="#5a5a5a" />
      {/* 弹匣 */}
      <rect x="8" y="15" width="2" height="4" fill="#2a2a2a" />
      {/* 枪管 */}
      <rect x="12" y="10" width="9" height="3" fill="#4a4a4a" />
      <rect x="20" y="10" width="3" height="3" fill="#2a2a2a" />
      {/* 准星 */}
      <rect x="15" y="7" width="1" height="2" fill="#6a6a6a" />
      <rect x="18" y="7" width="1" height="2" fill="#6a6a6a" />
      {/* 握把 */}
      <rect x="9" y="13" width="2" height="3" fill="#5a4a2a" />
    </svg>
  );
}

// 锈蚀匕首
function IconDagger({ size = 36 }) {
  const s = size / 24;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={{ imageRendering: 'pixelated' }}>
      {/* 刀刃 */}
      <rect x="11" y="2" width="2" height="14" fill="#8a7f5a" />
      <rect x="10" y="4" width="4" height="10" fill="#a89868" />
      <rect x="11" y="2" width="2" height="2" fill="#c0b080" />
      {/* 锈迹 */}
      <rect x="10" y="8" width="1" height="2" fill="#6b4423" />
      <rect x="13" y="10" width="1" height="1" fill="#6b4423" />
      <rect x="11" y="6" width="1" height="1" fill="#8b5a2b" />
      {/* 护手 */}
      <rect x="8" y="15" width="8" height="2" fill="#5a4a2a" />
      <rect x="8" y="15" width="8" height="1" fill="#7a6540" />
      {/* 握柄 */}
      <rect x="10" y="17" width="4" height="5" fill="#4a3828" />
      <rect x="10" y="17" width="4" height="1" fill="#6a5038" />
      {/* 柄头 */}
      <rect x="9" y="21" width="6" height="1" fill="#5a4a2a" />
    </svg>
  );
}

// 符文法典
function IconTome({ size = 36 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={{ imageRendering: 'pixelated' }}>
      {/* 书脊 */}
      <rect x="3" y="4" width="3" height="16" fill="#3d2418" />
      <rect x="3" y="4" width="1" height="16" fill="#5a3620" />
      {/* 封面 */}
      <rect x="6" y="4" width="15" height="16" fill="#4a3020" />
      <rect x="6" y="4" width="15" height="2" fill="#6a4830" />
      <rect x="6" y="4" width="2" height="16" fill="#3d2418" />
      {/* 符文 */}
      <rect x="12" y="8" width="3" height="1" fill="#9c27b0" />
      <rect x="11" y="10" width="5" height="1" fill="#9c27b0" />
      <rect x="12" y="12" width="3" height="1" fill="#9c27b0" />
      <rect x="13" y="14" width="1" height="2" fill="#9c27b0" />
      {/* 发光效果 */}
      <rect x="13" y="11" width="1" height="1" fill="#ce93d8">
        <animate attributeName="opacity" values="1;0.3;1" dur="2s" repeatCount="indefinite" />
      </rect>
      {/* 书页角 */}
      <rect x="19" y="18" width="2" height="2" fill="#d4c896" />
    </svg>
  );
}

// 异化触手
function IconTentacle({ size = 36 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={{ imageRendering: 'pixelated' }}>
      {/* 触手主体 */}
      <rect x="12" y="2" width="4" height="3" fill="#558b2f" />
      <rect x="11" y="5" width="5" height="3" fill="#689f38" />
      <rect x="10" y="8" width="5" height="3" fill="#7cb342" />
      <rect x="9" y="11" width="4" height="3" fill="#8bc34a" />
      <rect x="7" y="14" width="4" height="3" fill="#7cb342" />
      <rect x="5" y="16" width="4" height="3" fill="#689f38" />
      <rect x="3" y="18" width="4" height="3" fill="#558b2f" />
      <rect x="2" y="20" width="3" height="2" fill="#33691e" />
      {/* 吸盘 */}
      <rect x="13" y="4" width="2" height="1" fill="#2a3d1f" />
      <rect x="11" y="7" width="2" height="1" fill="#2a3d1f" />
      <rect x="10" y="10" width="2" height="1" fill="#2a3d1f" />
      <rect x="8" y="13" width="2" height="1" fill="#2a3d1f" />
      <rect x="6" y="16" width="2" height="1" fill="#2a3d1f" />
      {/* 发光尖端 */}
      <rect x="3" y="21" width="1" height="1" fill="#9c27b0">
        <animate attributeName="opacity" values="1;0.4;1" dur="1.5s" repeatCount="indefinite" />
      </rect>
    </svg>
  );
}

// 霰弹枪
function IconShotgun({ size = 60 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill="none" style={{ imageRendering: 'pixelated' }}>
      {/* 枪托 */}
      <rect x="2" y="18" width="10" height="12" fill="#5a3d2a" />
      <rect x="2" y="18" width="10" height="3" fill="#7a5540" />
      <rect x="2" y="27" width="10" height="3" fill="#3d2818" />
      {/* 机匣 */}
      <rect x="12" y="16" width="10" height="14" fill="#3d3d3d" />
      <rect x="12" y="16" width="10" height="3" fill="#5a5a5a" />
      <rect x="12" y="27" width="10" height="3" fill="#2a2a2a" />
      {/* 泵动护木 */}
      <rect x="14" y="30" width="8" height="5" fill="#5a3d2a" />
      <rect x="14" y="30" width="8" height="2" fill="#7a5540" />
      {/* 双枪管 */}
      <rect x="22" y="18" width="20" height="5" fill="#4a4a4a" />
      <rect x="22" y="25" width="20" height="5" fill="#4a4a4a" />
      <rect x="22" y="18" width="20" height="2" fill="#6a6a6a" />
      <rect x="22" y="25" width="20" height="2" fill="#6a6a6a" />
      <rect x="40" y="17" width="6" height="7" fill="#2a2a2a" />
      <rect x="40" y="24" width="6" height="7" fill="#2a2a2a" />
      {/* 准星 */}
      <rect x="30" y="15" width="2" height="3" fill="#6a6a6a" />
      {/* 扳机护圈 */}
      <rect x="16" y="27" width="4" height="5" fill="#2a2a2a" />
      <rect x="17" y="28" width="2" height="3" fill="#1a1a1a" />
      {/* 深渊光效 */}
      <rect x="42" y="19" width="2" height="2" fill="#9c27b0">
        <animate attributeName="opacity" values="1;0.3;1" dur="1.2s" repeatCount="indefinite" />
      </rect>
      <rect x="42" y="26" width="2" height="2" fill="#9c27b0">
        <animate attributeName="opacity" values="0.5;1;0.5" dur="1.2s" repeatCount="indefinite" />
      </rect>
    </svg>
  );
}

// 升级步枪
function IconRifleUpgrade({ size = 60 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill="none" style={{ imageRendering: 'pixelated' }}>
      {/* 枪托 */}
      <rect x="2" y="18" width="10" height="12" fill="#5a4a2a" />
      <rect x="2" y="18" width="10" height="3" fill="#7a6540" />
      {/* 机匣 */}
      <rect x="12" y="16" width="12" height="14" fill="#3d3d3d" />
      <rect x="12" y="16" width="12" height="3" fill="#5a5a5a" />
      {/* 瞄准镜 */}
      <rect x="14" y="12" width="8" height="4" fill="#2a2a2a" />
      <rect x="15" y="13" width="2" height="2" fill="#4db6ac" />
      {/* 弹匣 */}
      <rect x="16" y="28" width="4" height="8" fill="#2a2a2a" />
      {/* 枪管 */}
      <rect x="24" y="19" width="20" height="6" fill="#4a4a4a" />
      <rect x="24" y="19" width="20" height="2" fill="#6a6a6a" />
      <rect x="42" y="18" width="4" height="8" fill="#2a2a2a" />
      {/* 握把 */}
      <rect x="18" y="28" width="3" height="6" fill="#5a4a2a" />
      {/* 升级箭头 */}
      <rect x="36" y="6" width="3" height="6" fill="#c68c3b" />
      <rect x="34" y="8" width="7" height="3" fill="#c68c3b" />
      <rect x="35" y="4" width="5" height="3" fill="#daa520" />
      {/* 光效 */}
      <rect x="37" y="10" width="1" height="1" fill="#ffd700">
        <animate attributeName="opacity" values="1;0.3;1" dur="0.8s" repeatCount="indefinite" />
      </rect>
    </svg>
  );
}

// 古神之眼
function IconEye({ size = 60 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill="none" style={{ imageRendering: 'pixelated' }}>
      {/* 眼眶外轮廓 */}
      <rect x="6" y="18" width="4" height="12" fill="#5a3d5c" />
      <rect x="10" y="14" width="4" height="20" fill="#6a4a6c" />
      <rect x="14" y="10" width="4" height="28" fill="#7a557c" />
      <rect x="18" y="8" width="12" height="32" fill="#8a658c" />
      <rect x="30" y="10" width="4" height="28" fill="#7a557c" />
      <rect x="34" y="14" width="4" height="20" fill="#6a4a6c" />
      <rect x="38" y="18" width="4" height="12" fill="#5a3d5c" />
      {/* 眼白 */}
      <rect x="12" y="16" width="24" height="16" fill="#f0e6d0" />
      <rect x="16" y="14" width="16" height="20" fill="#f5edd8" />
      {/* 虹膜 */}
      <rect x="18" y="18" width="12" height="12" fill="#9c27b0" />
      <rect x="20" y="17" width="8" height="14" fill="#ab47bc" />
      {/* 瞳孔 */}
      <rect x="22" y="20" width="4" height="8" fill="#1a0a1a" />
      {/* 高光 */}
      <rect x="23" y="21" width="2" height="2" fill="#fff" />
      {/* 发光瞳孔 */}
      <rect x="22" y="22" width="4" height="4" fill="#ce93d8">
        <animate attributeName="opacity" values="0.6;1;0.6" dur="2s" repeatCount="indefinite" />
      </rect>
      {/* 血丝 */}
      <rect x="15" y="18" width="2" height="1" fill="#e57373" opacity="0.6" />
      <rect x="31" y="22" width="2" height="1" fill="#e57373" opacity="0.6" />
      <rect x="14" y="25" width="3" height="1" fill="#e57373" opacity="0.5" />
    </svg>
  );
}

// 蠕动之心
function IconHeart({ size = 60 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill="none" style={{ imageRendering: 'pixelated' }}>
      {/* 心脏主体 - 异形风格 */}
      {/* 左心房 */}
      <rect x="6" y="12" width="8" height="10" fill="#6b2a2a" />
      <rect x="4" y="14" width="4" height="8" fill="#5a1f1f" />
      {/* 右心房 */}
      <rect x="26" y="10" width="10" height="10" fill="#7a3030" />
      <rect x="34" y="12" width="6" height="6" fill="#6b2a2a" />
      {/* 心室主体 */}
      <rect x="10" y="18" width="24" height="16" fill="#8b3a3a" />
      <rect x="14" y="22" width="18" height="14" fill="#9c4a4a" />
      {/* 心尖 */}
      <rect x="18" y="32" width="12" height="8" fill="#7a3030" />
      <rect x="20" y="36" width="8" height="4" fill="#6b2a2a" />
      <rect x="22" y="38" width="4" height="2" fill="#5a1f1f" />
      {/* 血管/触手装饰 */}
      <rect x="8" y="10" width="3" height="4" fill="#4a1a1a" />
      <rect x="28" y="6" width="3" height="6" fill="#4a1a1a" />
      <rect x="36" y="18" width="4" height="3" fill="#4a1a1a" />
      <rect x="6" y="26" width="4" height="4" fill="#5a1f1f" />
      {/* 暗紫色脉络 */}
      <rect x="16" y="20" width="2" height="1" fill="#4a145a" />
      <rect x="20" y="24" width="3" height="1" fill="#4a145a" />
      <rect x="26" y="28" width="2" height="1" fill="#4a145a" />
      {/* 发光点 - 心跳效果 */}
      <rect x="22" y="26" width="4" height="4" fill="#ce93d8">
        <animate attributeName="opacity" values="0.3;1;0.3" dur="1s" repeatCount="indefinite" />
      </rect>
      <rect x="23" y="27" width="2" height="2" fill="#fff">
        <animate attributeName="opacity" values="0.5;1;0.5" dur="1s" repeatCount="indefinite" />
      </rect>
    </svg>
  );
}

// 霰弹枪 (小)
function IconShotgunSmall({ size = 36 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={{ imageRendering: 'pixelated' }}>
      <rect x="1" y="9" width="5" height="6" fill="#5a3d2a" />
      <rect x="6" y="8" width="5" height="7" fill="#3d3d3d" />
      <rect x="11" y="9" width="10" height="2" fill="#4a4a4a" />
      <rect x="11" y="12" width="10" height="2" fill="#4a4a4a" />
      <rect x="20" y="8" width="3" height="3" fill="#2a2a2a" />
      <rect x="20" y="11" width="3" height="3" fill="#2a2a2a" />
      <rect x="7" y="14" width="4" height="3" fill="#5a3d2a" />
    </svg>
  );
}

// 精灵弓
function IconBow({ size = 36 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={{ imageRendering: 'pixelated' }}>
      {/* 弓身 */}
      <rect x="5" y="3" width="2" height="3" fill="#c68c3b" />
      <rect x="4" y="5" width="2" height="3" fill="#d4a04a" />
      <rect x="3" y="7" width="2" height="10" fill="#d4a04a" />
      <rect x="4" y="16" width="2" height="3" fill="#c68c3b" />
      <rect x="5" y="19" width="2" height="2" fill="#a87420" />
      {/* 弓弦 */}
      <rect x="6" y="4" width="1" height="17" fill="#f0e6d0" />
      {/* 箭 */}
      <rect x="7" y="11" width="12" height="2" fill="#8a7540" />
      <rect x="17" y="10" width="3" height="4" fill="#c0c0c0" />
      <rect x="19" y="11" width="1" height="2" fill="#e0e0e0" />
      {/* 箭羽 */}
      <rect x="7" y="10" width="2" height="1" fill="#9c27b0" />
      <rect x="7" y="13" width="2" height="1" fill="#9c27b0" />
    </svg>
  );
}

// ============================================
// 武器数据
// ============================================
const weapons = [
  { id: 'rifle', name: '军用步枪', icon: IconRifle, equipped: true, damage: 20, fireRate: '中', special: '穿透+1' },
  { id: 'dagger', name: '锈蚀匕首', icon: IconDagger, equipped: false, damage: 15, fireRate: '快', special: '流血效果' },
  { id: 'tome', name: '符文法典', icon: IconTome, equipped: false, damage: 25, fireRate: '慢', special: '魔法伤害' },
  { id: 'tentacle', name: '异化触手', icon: IconTentacle, equipped: false, damage: 18, fireRate: '中', special: '范围攻击' },
  { id: 'shotgun', name: '霰弹枪', icon: IconShotgunSmall, equipped: false, damage: 40, fireRate: '慢', special: '5颗弹丸' },
  { id: 'bow', name: '精灵弓', icon: IconBow, equipped: false, damage: 22, fireRate: '中', special: '精准射击' },
];

// ============================================
// 属性数据
// ============================================
const initialStats = [
  { id: 'meleeDmg', name: '近战伤害', value: 15, suffix: '', color: 'green' },
  { id: 'meleeInc', name: '近战增伤', value: 10, suffix: '%', color: 'green' },
  { id: 'meleeSpeed', name: '近战攻速', value: 8, suffix: '%', color: 'gold' },
  { id: 'meleeCrit', name: '近战暴击', value: 5, suffix: '%', color: 'gold' },
  { id: 'meleeCritDmg', name: '近战爆伤', value: 20, suffix: '%', color: 'red' },
  { id: 'rangedDmg', name: '远程伤害', value: 12, suffix: '', color: 'green' },
  { id: 'projCount', name: '投射物数量', value: 1, suffix: '', color: 'gold' },
  { id: 'pierce', name: '穿透次数', value: 2, suffix: '', color: 'gold' },
  { id: 'rangedRange', name: '远程范围', value: 15, suffix: '%', color: 'teal' },
  { id: 'kinDmg', name: '眷族伤害', value: 8, suffix: '', color: 'purple' },
  { id: 'maxHp', name: '最大生命', value: 50, suffix: '', color: 'red' },
  { id: 'hpRegen', name: '每秒回血', value: 2, suffix: '', color: 'green' },
  { id: 'shield', name: '护盾', value: 20, suffix: '', color: 'blue' },
  { id: 'armor', name: '护甲', value: 5, suffix: '', color: 'gold' },
  { id: 'moveSpeed', name: '移动速度', value: 10, suffix: '%', color: 'teal' },
  { id: 'pickupRange', name: '拾取范围', value: 20, suffix: '%', color: 'gold' },
  { id: 'expGain', name: '经验获取', value: 15, suffix: '%', color: 'purple' },
  { id: 'dropRate', name: '掉落率', value: 10, suffix: '%', color: 'gold' },
  { id: 'luck', name: '幸运', value: 3, suffix: '', color: 'purple' },
  { id: 'coinGain', name: '货币获取', value: 25, suffix: '%', color: 'gold' },
];

// ============================================
// 卡片数据
// ============================================
const cardTemplates = [
  {
    id: 'abyss-shotgun',
    type: 'weapon',
    typeLabel: '新武器',
    name: '深渊霰弹枪',
    icon: IconShotgun,
    desc: '伤害25，攻速慢，近距离发射5颗弹丸，每颗伤害8，有几率使敌人恐惧',
    priceReward: '选择',
    priceShop: 500,
    statMap: { rangedDmg: 13, projCount: 4 },
  },
  {
    id: 'rifle-upgrade',
    type: 'upgrade',
    typeLabel: '武器升级',
    name: '军用步枪 · 强化',
    icon: IconRifleUpgrade,
    desc: '伤害+8，攻速+15%，弹匣容量+5，穿透+1',
    priceReward: '选择',
    priceShop: 300,
    statMap: { rangedDmg: 8, meleeSpeed: 15, pierce: 1 },
  },
  {
    id: 'old-god-eye',
    type: 'relic',
    typeLabel: '遗物',
    name: '古神之眼',
    icon: IconEye,
    desc: '暴击率+15%，暴击伤害+30%，击杀敌人时有10%几率触发虚空之眼射线',
    priceReward: '选择',
    priceShop: 800,
    statMap: { meleeCrit: 15, meleeCritDmg: 30 },
  },
  {
    id: 'writhing-heart',
    type: 'relic',
    typeLabel: '遗物',
    name: '蠕动之心',
    icon: IconHeart,
    desc: '最大生命+30，每秒回血+3，血量低于20%时移速+25%持续3秒（冷却30秒）',
    priceReward: '选择',
    priceShop: 600,
    statMap: { maxHp: 30, hpRegen: 3, moveSpeed: 5 },
  },
];

// ============================================
// 武器条组件
// ============================================
function WeaponBar() {
  const [load, setLoad] = useState(0);
  const maxLoad = 100;
  const currentLoad = 24;

  useEffect(() => {
    // 像素填充动画
    const interval = setInterval(() => {
      setLoad(prev => {
        if (prev >= currentLoad) {
          clearInterval(interval);
          return currentLoad;
        }
        return prev + 2;
      });
    }, 40);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="weapon-bar pixel-border">
      {/* 触手装饰 - 左 */}
      <svg className="tentacle-deco-left" viewBox="0 0 40 80" fill="none">
        <path d="M35,5 Q25,20 30,40 Q35,60 20,75" stroke="#3d5a2a" strokeWidth="6" strokeLinecap="round" fill="none"/>
        <path d="M35,5 Q25,20 30,40 Q35,60 20,75" stroke="#558b2f" strokeWidth="2" strokeLinecap="round" fill="none" opacity="0.5"/>
        <circle cx="28" cy="18" r="2" fill="#2a3d1f"/>
        <circle cx="30" cy="38" r="2.5" fill="#2a3d1f"/>
        <circle cx="24" cy="60" r="2" fill="#2a3d1f"/>
      </svg>

      {weapons.map((w, i) => {
        const IconComponent = w.icon;
        return (
          <div
            key={w.id}
            className={`weapon-slot ${w.equipped ? 'equipped' : ''}`}
            style={{ animationDelay: `${i * 0.08}s` }}
          >
            <div className="weapon-icon">
              <IconComponent size={36} />
            </div>
            <div className="weapon-name">{w.name}</div>
            <div className="weapon-tooltip">
              <div className="tooltip-title">{w.name}</div>
              <div className="tooltip-stat">伤害: {w.damage}</div>
              <div className="tooltip-stat">攻速: {w.fireRate}</div>
              <div className="tooltip-stat">{w.special}</div>
            </div>
          </div>
        );
      })}

      {/* 触手装饰 - 右 */}
      <svg className="tentacle-deco-right" viewBox="0 0 40 80" fill="none">
        <path d="M35,5 Q25,20 30,40 Q35,60 20,75" stroke="#3d5a2a" strokeWidth="6" strokeLinecap="round" fill="none"/>
        <path d="M35,5 Q25,20 30,40 Q35,60 20,75" stroke="#558b2f" strokeWidth="2" strokeLinecap="round" fill="none" opacity="0.5"/>
        <circle cx="28" cy="18" r="2" fill="#2a3d1f"/>
        <circle cx="30" cy="38" r="2.5" fill="#2a3d1f"/>
        <circle cx="24" cy="60" r="2" fill="#2a3d1f"/>
      </svg>

      {/* 负载条 */}
      <div className="load-container">
        <div className="load-label">负载 LOAD</div>
        <div className="load-value">{load} / {maxLoad}</div>
        <div className="pixel-progress">
          <div
            className="pixel-progress-fill"
            style={{
              width: `${(load / maxLoad) * 100}%`,
              background: load > 80
                ? 'linear-gradient(90deg, #b7410e, #e74c3c)'
                : 'linear-gradient(90deg, #558b2f, #7cb342)'
            }}
          />
        </div>
      </div>
    </div>
  );
}

// ============================================
// 属性栏组件
// ============================================
function StatsSidebar({ stats, flashingIds }) {
  return (
    <div className="stats-sidebar pixel-border">
      <div className="stats-header">
        <div className="stats-title">属性总览</div>
      </div>
      <div className="stats-list">
        {stats.map((stat, i) => (
          <div
            key={stat.id}
            className="stat-item"
            style={{ animation: `cardSlideIn 0.3s ease forwards`, animationDelay: `${i * 0.03}s`, opacity: 0 }}
          >
            <span className="stat-name">{stat.name}</span>
            <span className={`stat-value ${stat.color} ${flashingIds.includes(stat.id) ? 'flash' : ''}`}>
              +{stat.value}{stat.suffix}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ============================================
// 奖励卡片组件
// ============================================
function RewardCard({ card, mode, purchased, onSelect, index }) {
  const IconComponent = card.icon;
  const price = mode === 'reward' ? card.priceReward : card.priceShop;

  const handleClick = () => {
    if (!purchased) {
      onSelect(card);
    }
  };

  return (
    <div
      className={`reward-card type-${card.type} ${purchased ? 'purchased' : ''}`}
      onClick={handleClick}
      style={{ animationDelay: `${index * 0.1 + 0.1}s` }}
    >
      {/* 类型角标 */}
      <div className="type-badge">{card.typeLabel}</div>

      {/* 诡异微光 */}
      <div className="eerie-glow" style={{ '--glow-delay': `${index * 1.5}s` }}></div>

      {/* Icon 区域 */}
      <div className="card-icon-area">
        <div className="card-icon">
          <IconComponent size={60} />
        </div>
      </div>

      {/* 内容区 */}
      <div className="card-body">
        <div className="card-title">{card.name}</div>
        <div className="card-desc" dangerouslySetInnerHTML={{
          __html: card.desc
            .replace(/(\+[\d]+%?)/g, '<span class="stat-highlight">$1</span>')
            .replace(/(\d+[颗])/g, '<span class="stat-highlight">$1</span>')
        }} />
        <div className="card-bottom">
          <button
            className={`pixel-btn ${card.type === 'weapon' ? 'green' : card.type === 'relic' ? 'purple' : ''}`}
            disabled={purchased}
            onClick={(e) => { e.stopPropagation(); handleClick(); }}
          >
            {purchased ? '已获得' : (
              mode === 'shop' ? (
                <span className="price-display">
                  <span className="coin-icon"></span>
                  {price}
                </span>
              ) : price
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

// ============================================
// 金币粒子效果
// ============================================
function spawnCoinParticles(x, y) {
  const count = 12;
  for (let i = 0; i < count; i++) {
    const particle = document.createElement('div');
    particle.className = 'coin-particle';
    const angle = (Math.PI * 2 * i) / count + Math.random() * 0.5;
    const dist = 40 + Math.random() * 40;
    const dx = Math.cos(angle) * dist;
    const dy = Math.sin(angle) * dist - 30;
    particle.style.left = `${x}px`;
    particle.style.top = `${y}px`;
    particle.style.setProperty('--dx', `${dx}px`);
    particle.style.setProperty('--dy', `${dy}px`);
    document.body.appendChild(particle);
    setTimeout(() => particle.remove(), 800);
  }
}

// ============================================
// 主应用
// ============================================
function App() {
  const [mode, setMode] = useState('reward'); // reward | shop
  const [cards, setCards] = useState(cardTemplates);
  const [purchasedIds, setPurchasedIds] = useState([]);
  const [stats, setStats] = useState(initialStats);
  const [flashingIds, setFlashingIds] = useState([]);
  const [coins, setCoins] = useState(1500);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [cardKey, setCardKey] = useState(0); // 用于重触发入场动画

  // 生成雾气粒子
  useEffect(() => {
    const container = document.getElementById('fogParticles');
    if (!container) return;
    const particleCount = 15;
    for (let i = 0; i < particleCount; i++) {
      const p = document.createElement('div');
      p.className = 'fog-particle';
      const size = 80 + Math.random() * 120;
      p.style.width = `${size}px`;
      p.style.height = `${size}px`;
      p.style.left = `${Math.random() * 100}%`;
      p.style.animationDuration = `${15 + Math.random() * 20}s`;
      p.style.animationDelay = `${Math.random() * 20}s`;
      container.appendChild(p);
    }
  }, []);

  const handleSelect = useCallback((card) => {
    if (purchasedIds.includes(card.id)) return;

    if (mode === 'shop') {
      if (coins < card.priceShop) return;
      setCoins(c => c - card.priceShop);
    }

    // 更新属性
    const newFlashingIds = [];
    setStats(prevStats => {
      return prevStats.map(stat => {
        if (card.statMap && card.statMap[stat.id] !== undefined) {
          newFlashingIds.push(stat.id);
          return { ...stat, value: stat.value + card.statMap[stat.id] };
        }
        return stat;
      });
    });

    // 触发闪烁动画
    setFlashingIds(newFlashingIds);
    setTimeout(() => setFlashingIds([]), 600);

    // 标记已获得
    setPurchasedIds(prev => [...prev, card.id]);

    // 金币粒子效果
    if (mode === 'shop') {
      const button = document.activeElement;
      if (button) {
        const rect = button.getBoundingClientRect();
        spawnCoinParticles(rect.left + rect.width / 2, rect.top + rect.height / 2);
      }
    }
  }, [mode, purchasedIds, coins]);

  const handleRefresh = useCallback(() => {
    if (isRefreshing) return;
    setIsRefreshing(true);

    // 刷新消耗
    if (mode === 'shop') {
      setCoins(c => Math.max(0, c - 50));
    }

    // 重新打乱卡片（模拟刷新）
    setTimeout(() => {
      const shuffled = [...cardTemplates].sort(() => Math.random() - 0.5);
      setCards(shuffled);
      setPurchasedIds([]);
      setCardKey(k => k + 1);
      setIsRefreshing(false);
    }, 600);
  }, [isRefreshing, mode]);

  const handleSkip = useCallback(() => {
    // 跳过：直接刷新
    handleRefresh();
  }, [handleRefresh]);

  const switchMode = (newMode) => {
    if (newMode === mode) return;
    setMode(newMode);
    setPurchasedIds([]);
    setCards(cardTemplates);
    setCardKey(k => k + 1);
  };

  return (
    <div className="app-container">
      {/* 顶部武器条 */}
      <div className="weapon-bar-section">
        <WeaponBar />
      </div>

      {/* 中间主内容 */}
      <div className="main-content pixel-border">
        <h1 className="main-title">{mode === 'reward' ? '升 级 奖 励' : '商 店'}</h1>

        {/* 模式切换 */}
        <div className="mode-toggle">
          <button
            className={`mode-btn ${mode === 'reward' ? 'active' : ''}`}
            onClick={() => switchMode('reward')}
          >
            升级奖励
          </button>
          <button
            className={`mode-btn ${mode === 'shop' ? 'active' : ''}`}
            onClick={() => switchMode('shop')}
          >
            商店
          </button>
        </div>

        <div className="rune-divider">⚝ ✦ ⚝</div>

        {/* 卡片区域 */}
        <div className="cards-container" key={cardKey}>
          {cards.map((card, i) => (
            <RewardCard
              key={card.id}
              card={card}
              mode={mode}
              purchased={purchasedIds.includes(card.id)}
              onSelect={handleSelect}
              index={i}
            />
          ))}
        </div>

        {/* 底部按钮 */}
        <div className="action-buttons">
          <button className="action-btn" onClick={handleSkip}>
            <span>跳过</span>
          </button>
          <button
            className={`action-btn ${isRefreshing ? 'refresh-spinning' : ''}`}
            onClick={handleRefresh}
            disabled={isRefreshing}
          >
            <span className="refresh-icon">↻</span>
            <span>刷新</span>
            {mode === 'shop' && (
              <span style={{
                fontFamily: "'VT323', monospace",
                fontSize: '14px',
                color: 'var(--coin-gold)',
                marginLeft: '4px'
              }}>
                (-50)
              </span>
            )}
          </button>
          {mode === 'shop' && (
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              padding: '10px 16px',
              background: 'var(--bg-dark)',
              border: '2px solid var(--border-mid)',
              fontFamily: "'VT323', monospace",
              fontSize: '20px',
              color: 'var(--coin-gold)',
            }}>
              <span className="coin-icon" style={{ width: '12px', height: '12px' }}></span>
              {coins}
            </div>
          )}
        </div>
      </div>

      {/* 右侧属性栏 */}
      <StatsSidebar stats={stats} flashingIds={flashingIds} />
    </div>
  );
}

// 宣告可升级
function announceUpgrade() {
  try {
    window.parent.postMessage({ type: 'miaoda:upgrade:available', kind: 'interactive-prototype' }, '*');
  } catch (e) {}
}
announceUpgrade();
if (document.readyState !== 'complete') {
  window.addEventListener('load', announceUpgrade, { once: true });
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(React.createElement(App));
