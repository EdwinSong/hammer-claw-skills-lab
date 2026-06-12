# Hammer Claw Skills Lab

> 🔨 为 Hammer Miner 生态打造的技能市场 — 挖矿 x AI 的硬核技能平台

## 与 ESP-Claw Skills Lab 的关系

本项目 **fork 并大幅修改** 自 [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab)（MIT License）。

| 维度 | esp-claw-skills-lab | hammer-claw-skills-lab |
|------|---------------------|------------------------|
| **目标硬件** | ESP32-S3/C5/C6 通用开发板 | **BC08-P4** (ESP32-P4+C6+8×BM1370)、**Pockt** |
| **生态定位** | 通用 IoT AI Agent | **挖矿生态 + AI 生态** |
| **独有能力** | camera, imu, gpio, i2c 传感器 | **算力调控、电压/频率调节、芯片温控、矿池切换、风扇策略** |
| **技能分类** | game, utility, hardware, media, network, sensor, ai | ➕ **mining**（挖矿）、保留 game/utility/ai |
| **外设清单** | camera, led, motor, speaker, display, button... | ➕ **asic, fan, hashoard, psu, temp_sensor, vreg, argb_led** |
| **安装方式** | 设备端 LLM 通过 skills_lab_downloader 技能拉取 | ✅ 完全兼容原版安装流程 |
| **前端展示** | 独立网站 skills-lab.esp-claw.com | **设备出厂页面**（LVGL 原生页面，用户不可更改） |

### 代码继承声明

```
├── 继承自 esp-claw-skills-lab（MIT License）:
│   ├── build/vite-plugin-skills.ts      → 技能元数据扫描生成
│   ├── scripts/validate-skills.ts       → 技能格式校验
│   ├── src/config/allowlist.ts          → 分类/外设白名单（已扩展）
│   ├── src/types/                       → TypeScript 类型定义
│   ├── src/utils/                       → 工具函数
│   └── 整体 Vue 3 + Vite + TypeScript 架构
│
├── Hammer 定制:
│   ├── src/config/allowlist.ts          → 新增 mining 分类、矿机外设
│   ├── src/assets/                      → Hammer 品牌资源
│   ├── skills/                          → 矿机专属技能 + 精选复用官方技能
│   └── 设备端出厂页面（LVGL C 原生）
│
└── 可复用官方技能 (skills/):
    ├── flappybird/          ← 游戏
    ├── current_weather/     ← 天气
    ├── current_ip_info/     ← 网络信息
    ├── dino/                ← 小恐龙游戏
    ├── balance_ball/        ← 平衡球（需 IMU，Pockt 可用）
    └── ...（根据硬件兼容性筛选）
```

---

## 架构设计

### 整体数据流

```
┌─────────────────────────────────────────────────────────────┐
│  hammer-claw-skills-lab (GitHub 仓库)                        │
│                                                             │
│  skills/                     build/           src/          │
│  ├── miner_dashboard/        vite-plugin  →   generated/    │
│  ├── miner_overclock/        skills.ts        skills-data   │
│  ├── pool_switcher/             │              .json         │
│  ├── fan_control/               │              tags.json     │
│  ├── flappybird/   ← 复用       │                            │
│  └── ...                        ▼                            │
│                          npm run build                       │
│                          ┌──────────┐                        │
│                          │  dist/   │  ← 静态站点产物         │
│                          │  raw/    │  ← 技能源文件镜像       │
│                          └──────────┘                        │
└─────────────────────────────────────────────────────────────┘
         │                              │
         │ ① 技能安装（设备端 LLM）       │ ② 出厂页面（LVGL C）
         ▼                              ▼
┌─────────────────┐          ┌──────────────────────────┐
│  BC08-P4 设备    │          │  BC08-P4 factory page     │
│                 │          │  (LVGL 原生 Page X)        │
│  skills_lab_    │          │                          │
│  downloader     │          │  ┌────────────────────┐   │
│  技能拉取技能文件 │          │  │ Hammer Skills Lab  │   │
│  → /fatfs/      │          │  │ ────────────────── │   │
│    skills/      │          │  │ ⛏ Miner Dashboard  │   │
│                 │          │  │ ⚡ Overclock Guide  │   │
│                 │          │  │ 🌀 Fan Control     │   │
│                 │          │  │ 🌊 Pool Switcher   │   │
│                 │          │  │ 🎮 Flappy Bird     │   │
│                 │          │  │ ☀️ Current Weather  │   │
│                 │          │  │ ...                │   │
│                 │          │  │          [安装] →  │   │
│                 │          │  └────────────────────┘   │
│                 │          │                          │
│                 │          │  数据源: dist/skills-     │
│                 │          │  data.json (编译时嵌入)    │
└─────────────────┘          └──────────────────────────┘
```

### 与设备端的接口

设备出厂页面需要的数据结构（编译时嵌入固件）：

```typescript
// dist/skills-data.json — 编译时由 vite-plugin-skills.ts 生成
interface SkillsCatalog {
  generated_at: string;       // 生成时间戳
  skills: SkillEntry[];       // 技能列表
  tags_index: SkillTagsIndex; // 分类/标签/外设索引
}

interface SkillEntry {
  id: string;                 // 技能唯一标识 (如 "miner_dashboard")
  name: string;               // 与目录名一致
  description: string;        // 一句话描述（LLM 用）
  author: string;             // 作者
  title: string;              // 展示标题（从 SKILL.md H1 提取）
  metadata: {
    category: string[];       // ["mining", "utility"]
    peripherals: string[];    // ["asic", "fan", "display"]
    tags: string[];           // ["hashrate", "temperature"]
    cap_groups: string[];     // ["cap_miner", "cap_lua"]
  };
  extra_files: {
    references: string[];     // 如 ["guide.md"]
    scripts: string[];        // 如 ["dashboard.lua"]
    assets: string[];         // 如 ["icon.png"]
  };
  files: string[];            // 全部文件相对路径
  totalSize: number;          // 总大小（字节）
  featured: boolean;          // 是否精选
}
```

---

## 技能分类设计

### 新增 `mining` 分类

```typescript
// src/config/allowlist.ts (Hammer 扩展版)
export const ALLOWED_CATEGORIES = [
  'mining',    // 🆕 挖矿专属
  'game',      // 保留
  'utility',   // 保留
  'hardware',  // 保留
  'ai',        // 保留
  'network',   // 保留
  'media',     // 保留
  'sensor',    // 保留
] as const;

export const ALLOWED_PERIPHERALS = [
  // Hammer 矿机特有
  'asic',              // BM1370 ASIC 芯片
  'fan',               // 散热风扇
  'hashboard',         // 算力板
  'psu',               // 电源模块 (TPS546)
  'temp_sensor',       // 温度传感器 (TMP75)
  'vreg',              // 电压调节器
  'argb_led',          // WS2812B 灯带
  'frequency_controller', // 频率控制器
  // 保留官方
  'display',
  'button',
  'led',
  'camera',
  'speaker',
  'microphone',
  'motor',
  'gpio',
  'battery',
  'ir',
  'servo',
  'ws2812',
] as const;
```

---

## 计划技能清单

### 🔨 矿机专属（新增）

| 技能 ID | 标题 | 依赖外设 | 依赖 cap_groups | 说明 |
|---------|------|---------|-----------------|------|
| `miner_dashboard` | 矿机仪表盘 | asic, fan, temp_sensor | cap_miner | 实时算力/温度/收益面板 |
| `miner_overclock` | 安全超频向导 | asic, vreg, frequency_controller | cap_miner | 引导 LLM 逐步调频调压 |
| `pool_switcher` | 矿池切换 | - | cap_miner | 一键切换主/备矿池 |
| `fan_control` | 风扇策略 | fan, temp_sensor | cap_miner | 根据芯片温度自动调速 |
| `hashrate_monitor` | 算力监控 | asic | cap_miner | 历史算力曲线+异常告警 |
| `power_efficiency` | 能效分析 | psu, asic, vreg | cap_miner | 功耗/算力比优化建议 |
| `chip_health` | 芯片体检 | asic, temp_sensor | cap_miner | 逐芯片状态检测报告 |
| `rgb_mood` | 矿机氛围灯 | argb_led | cap_miner | 根据算力/温度变色 |

### 🎮 复用官方（筛选后）

| 技能 ID | 来源 | BC08 可用 | Pockt 可用 | 备注 |
|---------|------|-----------|------------|------|
| `flappybird` | 官方 | ✅ | ✅ | 已测试安装成功 |
| `current_weather` | 官方 | ✅ | ✅ | 需配 API |
| `current_ip_info` | 官方 | ✅ | ✅ | |
| `dino` | 官方 | ✅ | ✅ | 小恐龙游戏 |
| `github_repo_star` | 官方 | ✅ | ✅ | |
| `china_a_share_quote` | 官方 | ✅ | ✅ | A 股行情 |
| `clock_dial_demo` | 官方 | ✅ | ✅ | 表盘演示 |
| `balance_ball` | 官方 | ❌ 无 IMU | ✅ (如有) | 需加速度计 |
| `camera_preview` | 官方 | ❌ 无摄像头 | ❌ | |

---

## 项目结构

```
hammer-claw-skills-lab/
├── README.md                     # ← 本文件
├── LICENSE                       # MIT（继承自 esp-claw-skills-lab）
├── UPSTREAM.md                   # 上游追踪：记录 fork 来源和同步策略
│
├── skills/                       # 技能目录 ← 核心内容
│   ├── miner_dashboard/          # 🆕 矿机仪表盘
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   └── dashboard.lua
│   │   └── assets/
│   │       └── icon.png
│   ├── miner_overclock/          # 🆕 安全超频
│   ├── pool_switcher/            # 🆕 矿池切换
│   ├── fan_control/              # 🆕 风扇控制
│   ├── hashrate_monitor/         # 🆕 算力监控
│   ├── power_efficiency/         # 🆕 能效分析
│   ├── chip_health/              # 🆕 芯片体检
│   ├── rgb_mood/                 # 🆕 氛围灯
│   ├── flappybird/               # ← 复用官方
│   ├── current_weather/          # ← 复用官方
│   ├── dino/                     # ← 复用官方
│   └── ...
│
├── build/                        # 构建工具
│   └── vite-plugin-skills.ts     # Vite 插件：扫描 skills/ → 生成 JSON
│
├── scripts/                      # CI/工具脚本
│   └── validate-skills.ts        # 技能格式校验（CI gate）
│
├── src/                          # Web 前端（Vue 3 + Vite + TypeScript）
│   ├── App.vue
│   ├── main.ts
│   ├── config/
│   │   └── allowlist.ts          # 分类/外设白名单（Hammer 扩展版）
│   ├── components/               # Vue 组件
│   ├── composables/              # 组合式函数
│   ├── generated/                # 构建产物（gitignore）
│   │   ├── skills-data.json      # 技能元数据
│   │   └── tags.json             # 标签索引
│   ├── i18n/                     # 国际化（中文优先）
│   ├── router/                   # 路由
│   ├── stores/                   # Pinia 状态
│   ├── styles/                   # 样式
│   ├── types/                    # TS 类型定义
│   ├── utils/                    # 工具函数
│   └── views/                    # 页面视图
│
├── public/                       # 静态资源
│   └── favicon.svg
│
├── package.json                  # pnpm monorepo
├── pnpm-lock.yaml
├── pnpm-workspace.yaml
├── vite.config.ts                # Vite 配置
├── tsconfig.json
└── .github/workflows/            # CI/CD
    └── validate.yml              # 技能校验 + 构建
```

---

## 复用策略

### 从 esp-claw-skills-lab 同步官方技能的流程

```bash
# 1. 添加上游远程
git remote add upstream https://github.com/espressif/esp-claw-skills-lab.git

# 2. 拉取上游更新
git fetch upstream master

# 3. 挑选需要的技能目录
git checkout upstream/master -- skills/flappybird/
git checkout upstream/master -- skills/current_weather/
# ...

# 4. 运行校验
pnpm validate-skills

# 5. 提交
git commit -m "sync: upstream skills flappybird, current_weather"
```

### 不可复用的技能

以下官方技能因硬件依赖无法在 BC08 上运行：
- `camera_preview` — 需摄像头
- `balance_ball` — 需 IMU (BC08 无；Pockt 如有则可)
- `movement_detection` — 需 IMU
- `dfrobot_*` — 需 I2C 外设（BC08 I2C 被矿机占用）
- `unihiker_*` — 需 UNIHIKER 扩展板

这些技能保留在 `UPSTREAM.md` 中记录，不纳入 `skills/` 目录。

---

## 设备端出厂页面方案（Phase 2）

> ⚠️ 本次先讨论方案，不实现。此章节为设计稿。

### 页面布局

```
┌──────────────────────────────────┐
│  🔨 Hammer Skills Lab            │  ← 顶部标题栏（不可编辑）
│  ─────────────────────────────── │
│  [⛏ 挖矿] [🎮 游戏] [🔧 工具] [🤖 AI]│ ← 分类标签
│                                  │
│  ┌──────────────────────────────┐│
│  │ ⛏ Miner Dashboard           ││
│  │ 实时算力/温度/收益面板        ││  ← 技能卡片列表
│  │ 18.5 KB        [安装]        ││     (LVGL 原生渲染)
│  └──────────────────────────────┘│
│  ┌──────────────────────────────┐│
│  │ ⚡ Safe Overclock            ││
│  │ 引导 LLM 安全调频调压         ││
│  │ 12.3 KB        [安装]        ││
│  └──────────────────────────────┘│
│  ┌──────────────────────────────┐│
│  │ 🎮 Flappy Bird              ││
│  │ 经典小鸟飞行游戏              ││
│  │ 18.7 KB        [已安装 ✓]    ││
│  └──────────────────────────────┘│
│                                  │
│  数据源: skills-data.json        │  ← 编译时嵌入固件
│  ─────────────────────────────── │
│  [主页] [设置] [网络] [技能市场]   │  ← 底部导航栏
└──────────────────────────────────┘
```

### 技术实现要点

- **页面编号**：出厂页面使用 Page 7（保留 Page 4-6 给用户自定义 Lua 页面）
- **渲染方式**：LVGL C 原生渲染（非 Lua，确保性能和不被覆盖）
- **数据嵌入**：`skills-data.json` 通过 `EMBED_FILES` 编译进固件，运行时从 flash 读取
- **安装触发**：用户点击 [安装] → 调用 `skills_lab_downloader` 技能的 Lua 脚本
- **状态管理**：已安装/未安装状态通过检查 `/fatfs/skills/<id>/SKILL.md` 是否存在判断

---

## CI/CD

```yaml
# .github/workflows/validate.yml
name: Validate Skills
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: pnpm install
      - run: pnpm validate-skills   # 校验所有 SKILL.md 格式
      - run: pnpm build             # 构建前端 + 生成 skills-data.json
```

---

## 本地开发

```bash
# 环境要求
node >= 22.12.0
pnpm >= 11.0

# 安装依赖
pnpm install

# 启动开发服务器（预览 Web 前端）
pnpm dev

# 校验技能格式
pnpm validate-skills

# 构建产物
pnpm build
# → dist/            静态站点
# → dist/raw/        技能源文件镜像（供设备直接下载）
# → src/generated/skills-data.json  技能元数据（供固件嵌入）
```

---

## License

MIT License. 继承自 [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab).

原始版权声明见 [UPSTREAM.md](./UPSTREAM.md)。

---

## 相关项目

| 项目 | 说明 |
|------|------|
| [HammerMiner/BC08](https://github.com/HammerMiner/BC08) | BC08-P4 矿机固件 |
| [HammerMiner/Hammer-OS](https://github.com/HammerMiner/Hammer-OS) | Hammer OS 矿机操作系统 |
| [espressif/esp-claw](https://github.com/espressif/esp-claw) | ESP-Claw AI Agent 框架（上游） |
| [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab) | ESP-Claw Skills Lab（本项目的上游来源） |
