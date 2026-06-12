# 上游追踪

## Fork 来源

| 项目 | 仓库 | License |
|------|------|---------|
| **上游** | [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab) | MIT |
| **本项目** | [HammerMiner/hammer-claw-skills-lab](https://github.com/HammerMiner/hammer-claw-skills-lab) | MIT |

## 修改摘要

相对于上游 `espressif/esp-claw-skills-lab`，本项目做了以下大幅修改：

### 1. 技能分类扩展
- **新增 `mining` 分类**：挖矿专属技能（算力调控、电压调节、矿池管理等）
- 保留 `game`、`utility`、`ai`、`hardware`、`network`、`media`、`sensor`

### 2. 外设清单扩展
- **新增矿机外设**：`asic`、`fan`、`hashboard`、`psu`、`temp_sensor`、`vreg`、`argb_led`、`frequency_controller`
- 保留官方通用外设（`display`、`button`、`led` 等）

### 3. 技能内容
- **新增**：8+ 矿机专属技能（miner_dashboard、miner_overclock、pool_switcher 等）
- **复用**：精选官方技能（flappybird、current_weather、dino 等）
- **移除**：依赖不可用硬件的技能（camera_preview、balance_ball、dfrobot_*、unihiker_*）

### 4. 品牌与界面
- 品牌：ESP-Claw → Hammer Miner
- 配色/Logo：赛博朋克暗色主题
- 设备端：新增 LVGL 原生出厂页面（替代独立网站）

### 5. 目标平台
- BC08-P4：ESP32-P4 + C6 + 8×BM1370 ASIC（主要）
- Pockt：便携矿机（次要）

## 同步策略

### 定期同步
```bash
# 每季度检查上游更新
git fetch upstream master
git diff master upstream/master -- skills/   # 查看官方新增技能
git diff master upstream/master -- build/     # 查看构建工具更新
git diff master upstream/master -- src/       # 查看前端更新（通常不需要）

# 选择性合并
git checkout upstream/master -- skills/<new_skill>/
pnpm validate-skills
```

### 不追踪的部分
- `src/` 前端代码 → 我们使用设备端 LVGL 页面，不维护独立网站
- `.github/workflows/deploy.yml` → 无需部署到 Vercel/Cloudflare
- 依赖特定硬件的技能 → 在 `SKIP_LIST.md` 中记录

## 已跳过技能

| 技能 | 原因 |
|------|------|
| `camera_preview` | BC08 无摄像头 |
| `balance_ball` | BC08 无 IMU |
| `movement_detection` | BC08 无 IMU |
| `dfrobot_matrix_lidar_8x8_i2c` | I2C 被矿机占用 |
| `dfrobot_stcc4_i2c` | I2C 被矿机占用 |
| `unihiker_button` | 需 UNIHIKER 扩展板 |
| `unihiker_expansion_*` | 需 UNIHIKER 扩展板 |
| `lcd_touch_paint` | 需触摸屏（BC08 屏幕为显示面板） |

## 许可声明

本项目采用 MIT License，继承自上游 `espressif/esp-claw-skills-lab`。

原始版权声明：
```
MIT License
Copyright (c) 2026 Espressif Systems (Shanghai) CO LTD
```
