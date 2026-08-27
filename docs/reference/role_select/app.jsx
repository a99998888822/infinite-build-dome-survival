const { useState, useEffect, useRef } = React;

/* =========================================================
   像素SVG素材库
   ========================================================= */

// 古神之眼符号
const EyeSymbol = ({ size = 48, className = "" }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} className={className} shapeRendering="crispEdges">
    {/* 眼眶 */}
    <rect x="2" y="10" width="2" height="4" fill="#5a8a4a"/>
    <rect x="4" y="8" width="2" height="2" fill="#5a8a4a"/>
    <rect x="4" y="14" width="2" height="2" fill="#5a8a4a"/>
    <rect x="6" y="6" width="2" height="2" fill="#7a9a5c"/>
    <rect x="6" y="16" width="2" height="2" fill="#7a9a5c"/>
    <rect x="8" y="5" width="2" height="2" fill="#7a9a5c"/>
    <rect x="8" y="17" width="2" height="2" fill="#7a9a5c"/>
    <rect x="10" y="4" width="4" height="2" fill="#9ac86a"/>
    <rect x="10" y="18" width="4" height="2" fill="#9ac86a"/>
    <rect x="14" y="5" width="2" height="2" fill="#7a9a5c"/>
    <rect x="14" y="17" width="2" height="2" fill="#7a9a5c"/>
    <rect x="16" y="6" width="2" height="2" fill="#7a9a5c"/>
    <rect x="16" y="16" width="2" height="2" fill="#7a9a5c"/>
    <rect x="18" y="8" width="2" height="2" fill="#5a8a4a"/>
    <rect x="18" y="14" width="2" height="2" fill="#5a8a4a"/>
    <rect x="20" y="10" width="2" height="4" fill="#5a8a4a"/>
    {/* 眼白 */}
    <rect x="6" y="9" width="12" height="6" fill="#d8c898"/>
    <rect x="4" y="10" width="2" height="4" fill="#d8c898"/>
    <rect x="18" y="10" width="2" height="4" fill="#d8c898"/>
    {/* 瞳孔 */}
    <rect x="10" y="9" width="4" height="6" fill="#1a1a1a"/>
    <rect x="9" y="10" width="1" height="4" fill="#1a1a1a"/>
    <rect x="14" y="10" width="1" height="4" fill="#1a1a1a"/>
    {/* 高光 */}
    <rect x="11" y="10" width="1" height="1" fill="#9ac86a"/>
  </svg>
);

// 角落触手装饰
const CornerTentacle = ({ className = "" }) => (
  <svg viewBox="0 0 32 32" className={className} shapeRendering="crispEdges">
    <rect x="0" y="0" width="4" height="4" fill="#3d5a3f"/>
    <rect x="4" y="4" width="4" height="4" fill="#3d5a3f"/>
    <rect x="0" y="4" width="4" height="4" fill="#4a6a4a"/>
    <rect x="8" y="8" width="4" height="4" fill="#3d5a3f"/>
    <rect x="4" y="8" width="4" height="4" fill="#4a6a4a"/>
    <rect x="12" y="12" width="4" height="4" fill="#4a6a4a"/>
    <rect x="8" y="12" width="4" height="4" fill="#5a7a5a"/>
    <rect x="16" y="16" width="4" height="4" fill="#5a7a5a"/>
    <rect x="12" y="16" width="4" height="4" fill="#5a8a4a"/>
    <rect x="20" y="20" width="4" height="4" fill="#5a8a4a"/>
    <rect x="16" y="20" width="4" height="4" fill="#7a9a5c"/>
    <rect x="24" y="24" width="4" height="4" fill="#7a9a5c"/>
    <rect x="20" y="24" width="4" height="4" fill="#5a8a4a"/>
    {/* 吸盘 */}
    <rect x="6" y="6" width="2" height="2" fill="#2a3a2a"/>
    <rect x="14" y="10" width="2" height="2" fill="#2a3a2a"/>
    <rect x="18" y="18" width="2" height="2" fill="#2a3a2a"/>
    <rect x="22" y="22" width="2" height="2" fill="#2a3a2a"/>
  </svg>
);

/* =========================================================
   角色像素头像（32x32 小头像，128x128 放大显示）
   每个用 SVG rect 绘制 16x16 像素点阵
   ========================================================= */

// 老兵 · 马库斯 - 戴钢盔的士兵
const MarcusAvatar = ({ size = 40 }) => (
  <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
    {/* 钢盔 */}
    <rect x="4" y="2" width="8" height="1" fill="#4a5a4a"/>
    <rect x="3" y="3" width="10" height="2" fill="#5a6a5a"/>
    <rect x="2" y="5" width="12" height="1" fill="#4a5a4a"/>
    {/* 头盔带 */}
    <rect x="3" y="6" width="10" height="1" fill="#3a4a3a"/>
    {/* 脸 */}
    <rect x="5" y="7" width="6" height="4" fill="#c8a878"/>
    <rect x="4" y="8" width="1" height="3" fill="#b89868"/>
    <rect x="11" y="8" width="1" height="3" fill="#b89868"/>
    {/* 眼睛（严峻） */}
    <rect x="6" y="8" width="1" height="1" fill="#2a2018"/>
    <rect x="9" y="8" width="1" height="1" fill="#2a2018"/>
    {/* 眉 */}
    <rect x="6" y="7" width="2" height="1" fill="#5a3a28"/>
    <rect x="8" y="7" width="2" height="1" fill="#5a3a28"/>
    {/* 嘴 */}
    <rect x="7" y="10" width="2" height="1" fill="#8a5a48"/>
    {/* 胡茬 */}
    <rect x="5" y="11" width="6" height="1" fill="#7a5a3a"/>
    {/* 军服领子 */}
    <rect x="4" y="12" width="8" height="2" fill="#3a4a3a"/>
    <rect x="3" y="13" width="10" height="2" fill="#4a5a4a"/>
    <rect x="7" y="12" width="2" height="3" fill="#8a6a3a"/>
    <rect x="2" y="14" width="12" height="2" fill="#2a3a2a"/>
    {/* 伤痕 */}
    <rect x="8" y="6" width="1" height="2" fill="#b84a3a" opacity="0.6"/>
  </svg>
);

// 拾荒者 · 艾拉 - 带兜帽的女孩
const EllaAvatar = ({ size = 40 }) => (
  <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
    {/* 兜帽 */}
    <rect x="4" y="2" width="8" height="1" fill="#6a5a4a"/>
    <rect x="3" y="3" width="10" height="2" fill="#7a6a5a"/>
    <rect x="2" y="5" width="12" height="2" fill="#6a5a4a"/>
    <rect x="1" y="6" width="2" height="3" fill="#5a4a3a"/>
    <rect x="13" y="6" width="2" height="3" fill="#5a4a3a"/>
    {/* 脸 */}
    <rect x="5" y="7" width="6" height="4" fill="#e0c098"/>
    <rect x="4" y="8" width="1" height="3" fill="#d0b088"/>
    <rect x="11" y="8" width="1" height="3" fill="#d0b088"/>
    {/* 眼睛（灵动） */}
    <rect x="6" y="8" width="1" height="1" fill="#5a8ac4"/>
    <rect x="9" y="8" width="1" height="1" fill="#5a8ac4"/>
    <rect x="6" y="9" width="1" height="1" fill="#3a5a8a"/>
    <rect x="9" y="9" width="1" height="1" fill="#3a5a8a"/>
    {/* 俏皮的笑 */}
    <rect x="7" y="10" width="2" height="1" fill="#c87a6a"/>
    {/* 头发从兜帽露出 */}
    <rect x="5" y="5" width="1" height="2" fill="#c89a4a"/>
    <rect x="10" y="5" width="1" height="2" fill="#c89a4a"/>
    {/* 围巾 */}
    <rect x="4" y="11" width="8" height="1" fill="#8a4a3a"/>
    <rect x="3" y="12" width="10" height="2" fill="#6a5a4a"/>
    {/* 衣领 */}
    <rect x="5" y="12" width="6" height="1" fill="#5a4a3a"/>
    <rect x="2" y="14" width="12" height="2" fill="#3a3a2a"/>
    {/* 背包带 */}
    <rect x="4" y="13" width="1" height="3" fill="#5a4a3a"/>
    <rect x="11" y="13" width="1" height="3" fill="#5a4a3a"/>
  </svg>
);

// 学者 · 奥古斯特 - 戴单片眼镜的老者
const AugustAvatar = ({ size = 40 }) => (
  <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
    {/* 头发（灰白） */}
    <rect x="4" y="2" width="8" height="1" fill="#8a8a8a"/>
    <rect x="3" y="3" width="10" height="1" fill="#a8a8a8"/>
    <rect x="2" y="4" width="2" height="3" fill="#8a8a8a"/>
    <rect x="12" y="4" width="2" height="3" fill="#8a8a8a"/>
    {/* 发际线后退 */}
    <rect x="5" y="3" width="6" height="2" fill="#e0c8a8"/>
    {/* 脸 */}
    <rect x="4" y="6" width="8" height="5" fill="#e0c8a8"/>
    <rect x="3" y="7" width="1" height="3" fill="#d0b898"/>
    <rect x="12" y="7" width="1" height="3" fill="#d0b898"/>
    {/* 单片眼镜 */}
    <rect x="9" y="7" width="3" height="3" fill="none" stroke="#c49a4a" strokeWidth="1"/>
    <rect x="9" y="7" width="3" height="1" fill="#c49a4a"/>
    <rect x="9" y="9" width="3" height="1" fill="#c49a4a"/>
    <rect x="9" y="7" width="1" height="3" fill="#c49a4a"/>
    <rect x="11" y="7" width="1" height="3" fill="#c49a4a"/>
    {/* 眼睛 */}
    <rect x="6" y="8" width="1" height="1" fill="#3a2a18"/>
    <rect x="10" y="8" width="1" height="1" fill="#6a5ab8"/>
    {/* 眉 */}
    <rect x="5" y="7" width="2" height="1" fill="#5a5a5a"/>
    {/* 胡须（山羊胡） */}
    <rect x="6" y="11" width="4" height="1" fill="#7a7a7a"/>
    <rect x="7" y="10" width="2" height="1" fill="#8a8a8a"/>
    <rect x="7" y="11" width="2" height="2" fill="#6a6a6a"/>
    {/* 符文蔓延（脸颊） */}
    <rect x="12" y="8" width="1" height="2" fill="#6a5ab8" opacity="0.7"/>
    <rect x="11" y="9" width="1" height="1" fill="#8a6ac8" opacity="0.6"/>
    {/* 长袍 */}
    <rect x="3" y="12" width="10" height="2" fill="#3a2a4a"/>
    <rect x="2" y="14" width="12" height="2" fill="#2a1a3a"/>
    <rect x="7" y="12" width="2" height="3" fill="#c49a4a"/>
  </svg>
);

// 眷族混血 · 赛恩 - 半人半异形
const SainAvatar = ({ size = 40 }) => (
  <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
    {/* 头发（深色凌乱） */}
    <rect x="4" y="1" width="8" height="1" fill="#1a1a2a"/>
    <rect x="3" y="2" width="10" height="2" fill="#2a2a3a"/>
    <rect x="2" y="3" width="2" height="3" fill="#1a1a2a"/>
    <rect x="12" y="3" width="2" height="3" fill="#1a1a2a"/>
    {/* 脸（偏苍白） */}
    <rect x="4" y="5" width="8" height="5" fill="#c8b8a8"/>
    <rect x="3" y="6" width="1" height="3" fill="#b8a898"/>
    <rect x="12" y="6" width="1" height="3" fill="#b8a898"/>
    {/* 正常右眼 */}
    <rect x="6" y="7" width="1" height="1" fill="#2a2018"/>
    <rect x="5" y="7" width="1" height="1" fill="#4a3a28"/>
    {/* 异化左眼（发光绿） */}
    <rect x="9" y="6" width="2" height="3" fill="#1a3a1a"/>
    <rect x="9" y="7" width="2" height="1" fill="#5ac87a"/>
    <rect x="10" y="7" width="1" height="1" fill="#9af09a"/>
    {/* 眉 */}
    <rect x="5" y="6" width="2" height="1" fill="#3a2a18"/>
    <rect x="9" y="6" width="2" height="1" fill="#2a3a2a"/>
    {/* 嘴（冷漠） */}
    <rect x="7" y="10" width="2" height="1" fill="#5a4a3a"/>
    {/* 鳞片/异化皮肤纹理 */}
    <rect x="12" y="8" width="1" height="1" fill="#3a5a3a" opacity="0.6"/>
    <rect x="13" y="9" width="1" height="1" fill="#5a7a4a" opacity="0.5"/>
    <rect x="11" y="10" width="1" height="1" fill="#4a6a3a" opacity="0.4"/>
    {/* 脖子上的触手痕迹 */}
    <rect x="5" y="11" width="1" height="1" fill="#3a5a3a" opacity="0.6"/>
    <rect x="10" y="11" width="1" height="1" fill="#3a5a3a" opacity="0.6"/>
    {/* 深色衣服 */}
    <rect x="3" y="12" width="10" height="2" fill="#2a2a3a"/>
    <rect x="2" y="14" width="12" height="2" fill="#1a1a2a"/>
    <rect x="7" y="12" width="2" height="3" fill="#5a8a4a" opacity="0.6"/>
    {/* 衣领的触手装饰 */}
    <rect x="6" y="12" width="1" height="1" fill="#3a5a3a"/>
    <rect x="9" y="12" width="1" height="1" fill="#3a5a3a"/>
  </svg>
);

/* =========================================================
   武器图标
   ========================================================= */
const WeaponRifle = ({ size = 32 }) => (
  <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
    <rect x="2" y="7" width="10" height="2" fill="#6a5a4a"/>
    <rect x="12" y="6" width="2" height="1" fill="#5a4a3a"/>
    <rect x="12" y="8" width="2" height="1" fill="#5a4a3a"/>
    <rect x="14" y="7" width="1" height="2" fill="#3a3a3a"/>
    <rect x="3" y="9" width="3" height="3" fill="#5a4a3a"/>
    <rect x="2" y="10" width="1" height="2" fill="#4a3a2a"/>
    <rect x="9" y="6" width="2" height="1" fill="#8a6a3a"/>
    <rect x="8" y="5" width="1" height="1" fill="#8a6a3a"/>
  </svg>
);

const WeaponDagger = ({ size = 32 }) => (
  <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
    <rect x="7" y="1" width="2" height="8" fill="#a8a898"/>
    <rect x="6" y="2" width="1" height="6" fill="#8a8a7a"/>
    <rect x="9" y="2" width="1" height="6" fill="#c8c8b8"/>
    <rect x="5" y="9" width="6" height="1" fill="#c49a4a"/>
    <rect x="4" y="10" width="1" height="1" fill="#8a6a3a"/>
    <rect x="11" y="10" width="1" height="1" fill="#8a6a3a"/>
    <rect x="6" y="10" width="4" height="3" fill="#5a3a28"/>
    <rect x="7" y="13" width="2" height="2" fill="#3a2a18"/>
    {/* 锈迹 */}
    <rect x="7" y="4" width="1" height="1" fill="#8a5a3a" opacity="0.6"/>
    <rect x="8" y="6" width="1" height="1" fill="#a86a3a" opacity="0.5"/>
  </svg>
);

const WeaponCodex = ({ size = 32 }) => (
  <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
    <rect x="3" y="2" width="10" height="12" fill="#3a2a4a"/>
    <rect x="4" y="3" width="8" height="10" fill="#4a3a5a"/>
    <rect x="7" y="2" width="2" height="12" fill="#2a1a3a"/>
    {/* 符文 */}
    <rect x="5" y="5" width="2" height="1" fill="#9ac86a"/>
    <rect x="6" y="4" width="1" height="1" fill="#9ac86a"/>
    <rect x="6" y="6" width="1" height="1" fill="#9ac86a"/>
    <rect x="9" y="5" width="2" height="1" fill="#9ac86a"/>
    <rect x="9" y="4" width="1" height="1" fill="#9ac86a"/>
    <rect x="9" y="6" width="1" height="1" fill="#9ac86a"/>
    <rect x="5" y="8" width="6" height="1" fill="#c49a4a"/>
    <rect x="7" y="10" width="2" height="2" fill="#c49a4a"/>
    <rect x="3" y="2" width="1" height="12" fill="#5a4a6a"/>
    <rect x="12" y="2" width="1" height="12" fill="#5a4a6a"/>
  </svg>
);

const WeaponTentacle = ({ size = 32 }) => (
  <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
    <rect x="7" y="1" width="2" height="2" fill="#5a8a4a"/>
    <rect x="6" y="3" width="4" height="2" fill="#4a7a3a"/>
    <rect x="5" y="5" width="2" height="2" fill="#5a8a4a"/>
    <rect x="9" y="5" width="2" height="2" fill="#4a7a3a"/>
    <rect x="4" y="7" width="2" height="2" fill="#5a8a4a"/>
    <rect x="10" y="7" width="2" height="2" fill="#3a6a2a"/>
    <rect x="3" y="9" width="2" height="2" fill="#4a7a3a"/>
    <rect x="11" y="9" width="2" height="2" fill="#4a7a3a"/>
    <rect x="4" y="11" width="2" height="2" fill="#3a6a2a"/>
    <rect x="10" y="11" width="2" height="2" fill="#5a8a4a"/>
    <rect x="5" y="13" width="2" height="2" fill="#4a7a3a"/>
    <rect x="9" y="13" width="2" height="2" fill="#3a6a2a"/>
    <rect x="7" y="14" width="2" height="1" fill="#5a8a4a"/>
    {/* 吸盘 */}
    <rect x="6" y="4" width="1" height="1" fill="#2a4a1a"/>
    <rect x="9" y="6" width="1" height="1" fill="#2a4a1a"/>
    <rect x="5" y="8" width="1" height="1" fill="#2a4a1a"/>
    <rect x="10" y="10" width="1" height="1" fill="#2a4a1a"/>
    <rect x="6" y="12" width="1" height="1" fill="#2a4a1a"/>
  </svg>
);

/* =========================================================
   特性图标
   ========================================================= */
const TraitIcon = ({ type, size = 24 }) => {
  const icons = {
    instinct: (
      <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
        <rect x="7" y="2" width="2" height="2" fill="#b84a3a"/>
        <rect x="5" y="4" width="6" height="2" fill="#d86a4a"/>
        <rect x="4" y="6" width="8" height="4" fill="#b84a3a"/>
        <rect x="5" y="10" width="6" height="2" fill="#9a3a2a"/>
        <rect x="6" y="12" width="4" height="2" fill="#7a2a1a"/>
        <rect x="6" y="7" width="1" height="2" fill="#ffffff" opacity="0.4"/>
      </svg>
    ),
    ammo: (
      <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
        <rect x="4" y="3" width="2" height="8" fill="#c49a4a"/>
        <rect x="4" y="3" width="2" height="2" fill="#e8c878"/>
        <rect x="7" y="3" width="2" height="8" fill="#c49a4a"/>
        <rect x="7" y="3" width="2" height="2" fill="#e8c878"/>
        <rect x="10" y="3" width="2" height="8" fill="#c49a4a"/>
        <rect x="10" y="3" width="2" height="2" fill="#e8c878"/>
        <rect x="3" y="11" width="10" height="2" fill="#5a4a3a"/>
      </svg>
    ),
    luck: (
      <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
        <rect x="7" y="1" width="2" height="2" fill="#c49a4a"/>
        <rect x="5" y="3" width="6" height="1" fill="#e8c878"/>
        <rect x="4" y="4" width="8" height="4" fill="#c49a4a"/>
        <rect x="5" y="8" width="6" height="2" fill="#a87a3a"/>
        <rect x="6" y="10" width="4" height="2" fill="#8a6a2a"/>
        <rect x="7" y="12" width="2" height="3" fill="#6a4a1a"/>
        <rect x="6" y="5" width="1" height="1" fill="#ffffff" opacity="0.5"/>
      </svg>
    ),
    backpack: (
      <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
        <rect x="4" y="3" width="8" height="10" fill="#6a5a4a"/>
        <rect x="3" y="4" width="1" height="8" fill="#5a4a3a"/>
        <rect x="12" y="4" width="1" height="8" fill="#5a4a3a"/>
        <rect x="5" y="5" width="6" height="6" fill="#7a6a5a"/>
        <rect x="6" y="6" width="4" height="1" fill="#c49a4a"/>
        <rect x="7" y="7" width="2" height="3" fill="#c49a4a"/>
        <rect x="5" y="2" width="2" height="2" fill="#4a3a2a"/>
        <rect x="9" y="2" width="2" height="2" fill="#4a3a2a"/>
      </svg>
    ),
    arcane: (
      <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
        <rect x="7" y="2" width="2" height="1" fill="#9ac86a"/>
        <rect x="5" y="3" width="6" height="1" fill="#7aa85a"/>
        <rect x="4" y="4" width="8" height="1" fill="#5a8a4a"/>
        <rect x="3" y="5" width="10" height="6" fill="#4a7a3a"/>
        <rect x="4" y="11" width="8" height="1" fill="#5a8a4a"/>
        <rect x="5" y="12" width="6" height="1" fill="#7aa85a"/>
        <rect x="7" y="13" width="2" height="1" fill="#9ac86a"/>
        <rect x="7" y="6" width="2" height="4" fill="#c49a4a"/>
        <rect x="6" y="7" width="1" height="2" fill="#c49a4a"/>
        <rect x="9" y="7" width="1" height="2" fill="#c49a4a"/>
      </svg>
    ),
    resonance: (
      <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
        <rect x="7" y="7" width="2" height="2" fill="#a85ab8"/>
        <rect x="5" y="5" width="2" height="2" fill="#8a3a9a"/>
        <rect x="9" y="5" width="2" height="2" fill="#8a3a9a"/>
        <rect x="5" y="9" width="2" height="2" fill="#8a3a9a"/>
        <rect x="9" y="9" width="2" height="2" fill="#8a3a9a"/>
        <rect x="7" y="3" width="2" height="2" fill="#6a2a7a"/>
        <rect x="7" y="11" width="2" height="2" fill="#6a2a7a"/>
        <rect x="3" y="7" width="2" height="2" fill="#6a2a7a"/>
        <rect x="11" y="7" width="2" height="2" fill="#6a2a7a"/>
        <rect x="7" y="7" width="2" height="2" fill="#d87ae8"/>
      </svg>
    ),
    bloodline: (
      <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
        <rect x="6" y="2" width="4" height="2" fill="#5a8a4a"/>
        <rect x="5" y="4" width="6" height="3" fill="#4a7a3a"/>
        <rect x="4" y="7" width="8" height="4" fill="#3a6a2a"/>
        <rect x="5" y="11" width="3" height="3" fill="#4a7a3a"/>
        <rect x="8" y="11" width="3" height="3" fill="#4a7a3a"/>
        <rect x="6" y="5" width="1" height="1" fill="#9ac86a"/>
        <rect x="9" y="5" width="1" height="1" fill="#9ac86a"/>
        <rect x="7" y="8" width="2" height="1" fill="#9ac86a"/>
      </svg>
    ),
    unnameable: (
      <svg viewBox="0 0 16 16" width={size} height={size} shapeRendering="crispEdges">
        <rect x="7" y="1" width="2" height="2" fill="#6a3a8a"/>
        <rect x="5" y="3" width="6" height="2" fill="#7a4a9a"/>
        <rect x="4" y="5" width="8" height="2" fill="#8a5aa8"/>
        <rect x="3" y="7" width="10" height="4" fill="#9a6ab8"/>
        <rect x="4" y="11" width="8" height="2" fill="#7a4a9a"/>
        <rect x="5" y="13" width="6" height="2" fill="#5a3a7a"/>
        <rect x="6" y="6" width="1" height="2" fill="#d89ae8"/>
        <rect x="9" y="6" width="1" height="2" fill="#d89ae8"/>
        <rect x="7" y="9" width="2" height="1" fill="#ffffff" opacity="0.5"/>
      </svg>
    ),
  };
  return icons[type] || null;
};

/* =========================================================
   数据
   ========================================================= */

const characters = [
  {
    id: 'marcus',
    name: '老兵 · 马库斯',
    title: 'MARCUS · THE VETERAN',
    desc: '前穹顶守卫军中士，在第三次深渊潮汐中失去了整个小队。他握紧生锈的步枪，誓要查清穹顶之下的真相。',
    stats: { hp: 120, dmg: 15, atkSpd: 50, moveSpd: 50, luck: 25 },
    weapon: { name: '军用步枪', desc: '远程，中等射速，稳定射击', icon: 'rifle' },
    traits: [
      { name: '战场直觉', desc: '血量低于30%时伤害+30%', icon: 'instinct' },
      { name: '弹药专家', desc: '远程武器弹药+2', icon: 'ammo' },
    ],
    Avatar: MarcusAvatar,
  },
  {
    id: 'ella',
    name: '拾荒者 · 艾拉',
    title: 'ELLA · THE SCAVENGER',
    desc: '在废墟中长大的孤儿，靠捡拾旧世界遗物为生。她的背包里永远藏着意想不到的东西，也藏着不该被唤醒的低语。',
    stats: { hp: 90, dmg: 10, atkSpd: 80, moveSpd: 75, luck: 90 },
    weapon: { name: '锈蚀匕首', desc: '近战，快速挥砍，暴击率+10%', icon: 'dagger' },
    traits: [
      { name: '幸运儿', desc: '掉落率+25%', icon: 'luck' },
      { name: '应急背包', desc: '每局开始随机获得1件普通遗物', icon: 'backpack' },
    ],
    Avatar: EllaAvatar,
  },
  {
    id: 'august',
    name: '学者 · 奥古斯特',
    title: 'AUGUST · THE SCHOLAR',
    desc: '穹顶图书馆的最后一位管理员，痴迷于研究不可名状的古籍。他的知识既是武器也是诅咒，书页上的符文正在他皮肤上蔓延。',
    stats: { hp: 80, dmg: 18, atkSpd: 30, moveSpd: 30, luck: 50 },
    weapon: { name: '符文法典', desc: '远程，发射追踪法球，伤害高但射速慢', icon: 'codex' },
    traits: [
      { name: '秘法精通', desc: '经验获取+30%', icon: 'arcane' },
      { name: '深渊共鸣', desc: '每持有1件遗物，伤害+3%', icon: 'resonance' },
    ],
    Avatar: AugustAvatar,
  },
  {
    id: 'sain',
    name: '眷族混血 · 赛恩',
    title: 'SAIN · THE HALFBLOOD',
    desc: '母亲是人类，父亲是……不该存在的东西。他的左眼在黑暗中会发出幽绿的光，穹顶之下的存在似乎对他低语着什么。',
    stats: { hp: 110, dmg: 12, atkSpd: 55, moveSpd: 55, luck: 55 },
    weapon: { name: '异化触手', desc: '近战，范围攻击，攻击时有几率使敌人减速', icon: 'tentacle' },
    traits: [
      { name: '深渊血统', desc: '击杀敌人有5%几率召唤眷族助战', icon: 'bloodline' },
      { name: '不可名状之躯', desc: '受到致命伤害时有20%几率保留1点生命（每局限1次）', icon: 'unnameable' },
    ],
    Avatar: SainAvatar,
  },
];

const difficulties = [
  { id: 'easy', name: 'EASY', nameCn: '简单', bonus: '敌人血量-20%，掉落率+10%', cls: 'diff-easy' },
  { id: 'normal', name: 'NORMAL', nameCn: '普通', bonus: '标准难度，无加成', cls: 'diff-normal' },
  { id: 'hard', name: 'HARD', nameCn: '困难', bonus: '敌人血量+30%，伤害+20%，掉落率+20%，经验+15%', cls: 'diff-hard' },
  { id: 'nightmare', name: 'NIGHTMARE', nameCn: '噩梦', bonus: '敌人血量+60%，伤害+50%，移速+20%，掉落率+40%，经验+30%，解锁隐藏结局', cls: 'diff-nightmare' },
];

const weaponIcons = {
  rifle: WeaponRifle,
  dagger: WeaponDagger,
  codex: WeaponCodex,
  tentacle: WeaponTentacle,
};

const statLabels = [
  { key: 'hp', label: 'HP', color: 'var(--hp-color)', max: 150, display: v => v },
  { key: 'dmg', label: 'DMG', color: 'var(--dmg-color)', max: 25, display: v => v },
  { key: 'atkSpd', label: 'ATK SPD', color: '#c89a4a', max: 100, display: v => v < 40 ? '慢' : v < 70 ? '中' : '快' },
  { key: 'moveSpd', label: 'MOVE SPD', color: 'var(--spd-color)', max: 100, display: v => v < 40 ? '慢' : v < 70 ? '中' : '快' },
  { key: 'luck', label: 'LUCK', color: 'var(--luck-color)', max: 100, display: v => v < 30 ? '低' : v < 70 ? '中' : '高' },
];

/* =========================================================
   组件
   ========================================================= */

// 雾气粒子背景
function FogParticles() {
  const particles = [];
  for (let i = 0; i < 40; i++) {
    const left = Math.random() * 100;
    const top = Math.random() * 100;
    const duration = 8 + Math.random() * 12;
    const delay = Math.random() * 10;
    const dx = (Math.random() - 0.3) * 200;
    const dy = -(100 + Math.random() * 200);
    const size = 1 + Math.floor(Math.random() * 3);
    particles.push(
      <div
        key={i}
        className="fog-particle"
        style={{
          left: `${left}%`,
          top: `${top}%`,
          width: `${size}px`,
          height: `${size}px`,
          animationDuration: `${duration}s`,
          animationDelay: `${delay}s`,
          '--dx': `${dx}px`,
          '--dy': `${dy}px`,
        }}
      />
    );
  }
  return <>{particles}</>;
}

// 符文闪烁
function RuneFlashes() {
  const flashes = [];
  for (let i = 0; i < 6; i++) {
    flashes.push(
      <div
        key={i}
        className="rune-flash"
        style={{
          left: `${Math.random() * 90 + 5}%`,
          top: `${Math.random() * 80 + 10}%`,
          animationDelay: `${i * 1.3}s`,
        }}
      />
    );
  }
  return <>{flashes}</>;
}

// 属性进度条
function StatBar({ label, value, max, color, displayValue }) {
  const pct = Math.min(100, (value / max) * 100);
  return (
    <div className="stat-row">
      <span className="stat-label">{label}</span>
      <div className="stat-bar-wrap">
        <div
          className="stat-bar-fill"
          style={{ width: `${pct}%`, background: color }}
        />
      </div>
      <span className="stat-value">{displayValue}</span>
    </div>
  );
}

/* =========================================================
   主应用
   ========================================================= */

function App() {
  const [selectedChar, setSelectedChar] = useState('marcus');
  const [selectedDiff, setSelectedDiff] = useState('normal');
  const [transitionKey, setTransitionKey] = useState(0);
  const [showConfirm, setShowConfirm] = useState(false);
  const [confirmPhase, setConfirmPhase] = useState('idle');

  const char = characters.find(c => c.id === selectedChar);
  const diff = difficulties.find(d => d.id === selectedDiff);
  const WeaponIcon = weaponIcons[char.weapon.icon];

  const handleCharSelect = (id) => {
    if (id === selectedChar) return;
    setSelectedChar(id);
    setTransitionKey(k => k + 1);
  };

  const handleContinue = () => {
    setShowConfirm(true);
    setConfirmPhase('entering');
    setTimeout(() => setConfirmPhase('text'), 400);
    setTimeout(() => {
      setConfirmPhase('leaving');
      setTimeout(() => {
        setShowConfirm(false);
        setConfirmPhase('idle');
      }, 500);
    }, 2000);
  };

  return (
    <>
      {/* 背景层 */}
      <div className="bg-wrap">
        <div className="bg-pattern" />
        <FogParticles />
        <div className="crt-vignette" />
        <div className="crt-scanlines" />
        <RuneFlashes />
      </div>

      {/* 角落触手 */}
      <CornerTentacle className="corner-tentacle corner-tl" />
      <CornerTentacle className="corner-tentacle corner-tr" />
      <CornerTentacle className="corner-tentacle corner-bl" />
      <CornerTentacle className="corner-tentacle corner-br" />

      {/* 主内容 */}
      <div className="app">
        {/* 顶部标题 */}
        <header className="header">
          <EyeSymbol size={48} className="eye-symbol" />
          <div className="title-group">
            <h1 className="title-main">选择角色</h1>
            <div className="title-sub">SELECT SURVIVOR</div>
          </div>
          <EyeSymbol size={48} className="eye-symbol" />
        </header>

        {/* 主体三栏 */}
        <div className="main-body">
          {/* 左：角色列表 */}
          <div className="pixel-border">
            <div className="panel-title">SURVIVORS</div>
            <div className="char-list">
              {characters.map(c => (
                <div
                  key={c.id}
                  className={`char-item ${c.id === selectedChar ? 'selected' : ''}`}
                  onClick={() => handleCharSelect(c.id)}
                >
                  <c.Avatar size={40} className="char-avatar-small" />
                  <div>
                    <div className="char-name">{c.name.split(' · ')[1]}</div>
                    <div className="char-name-sub">{c.name.split(' · ')[0]}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* 中：角色详情 + 属性 */}
          <div className="center-col">
            {/* 角色详情 */}
            <div className="pixel-border char-detail">
              <div key={`avatar-${transitionKey}`} className="fade-slide-enter">
                <char.Avatar size={128} className="char-avatar-large" />
              </div>
              <div className="char-info" key={`info-${transitionKey}`}>
                <div className="fade-slide-enter">
                  <div className="char-detail-name">{char.name.split(' · ')[1]}</div>
                  <div className="char-detail-title">{char.title}</div>
                  <p className="char-desc">{char.desc}</p>
                </div>
              </div>
            </div>

            {/* 属性面板 */}
            <div className="pixel-border stats-panel" key={`stats-${transitionKey}`}>
              <div className="sub-section-title">◆ 基础属性</div>
              <div className="fade-slide-enter" style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {statLabels.map(s => (
                  <StatBar
                    key={s.key}
                    label={s.label}
                    value={char.stats[s.key]}
                    max={s.max}
                    color={s.color}
                    displayValue={s.display(char.stats[s.key])}
                  />
                ))}
              </div>

              <div className="sub-section-title">◆ 初始武器</div>
              <div className="weapon-box fade-slide-enter">
                <WeaponIcon size={32} className="weapon-icon" />
                <div className="weapon-info">
                  <div className="weapon-name">{char.weapon.name}</div>
                  <div className="weapon-desc">{char.weapon.desc}</div>
                </div>
              </div>

              <div className="sub-section-title">◆ 角色特性</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {char.traits.map((t, i) => (
                  <div key={t.name} className="trait-box fade-slide-enter" style={{ animationDelay: `${i * 0.1}s` }}>
                    <TraitIcon type={t.icon} size={24} className="trait-icon" />
                    <div className="trait-info">
                      <div className="trait-name">【{t.name}】</div>
                      <div className="trait-desc">{t.desc}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* 右：难度选择 */}
          <div className="pixel-border right-col">
            <div className="panel-title">DIFFICULTY</div>
            <div className="diff-list">
              {difficulties.map(d => (
                <div
                  key={d.id}
                  className={`diff-item ${d.cls} ${d.id === selectedDiff ? 'selected' : ''}`}
                  onClick={() => setSelectedDiff(d.id)}
                >
                  <div className="diff-name">
                    {d.name}
                    <span className="diff-name-cn">{d.nameCn}</span>
                  </div>
                  <div className="diff-bonus">{d.bonus}</div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* 底部按钮 */}
        <footer className="footer">
          <button className="pixel-btn" onClick={() => {}}>← 返回主界面</button>
          <button className="pixel-btn btn-primary" onClick={handleContinue}>
            继续 ▶
          </button>
        </footer>
      </div>

      {/* 底部诡秘提示 */}
      <div className="bottom-whisper">✦ 深渊凝视着你 ✦</div>

      {/* 确认动画 */}
      {showConfirm && (
        <div className="confirm-overlay" style={{ opacity: confirmPhase === 'leaving' ? 0 : 1, transition: 'opacity 0.5s steps(5)' }}>
          {confirmPhase !== 'entering' && (
            <div className="confirm-text">进入深渊</div>
          )}
        </div>
      )}
    </>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
