# BC08-P4 屏幕端技能市场 — 详细设计规划

> Phase 2 规划文档。本文定义 LVGL 原生技能市场页面的完整交互、数据结构、状态机和 API 需求。**先不做代码实现。**

---

## 1. 页面定位

| 属性 | 值 |
|------|-----|
| **页面编号** | Page 7（出厂页面，不可被用户 Lua 覆盖） |
| **渲染引擎** | LVGL C 原生（非 Lua，保证流畅度和不被篡改） |
| **底部栏入口** | 🛒 图标 |
| **编译方式** | 固件内置，随 BC08 版本发布 |

Page 4-6 留给用户自定义 Lua 页面，Page 7 是出厂技能市场。

---

## 2. 数据架构

### 2.1 数据源分层

```
┌──────────────────────────────────────────────────┐
│  编译时（固件内置）                                 │
│  ┌──────────────────────────────────────────┐    │
│  │ skills-data.json  (EMBED_FILES)           │    │
│  │  ├── skills[]         技能元数据（静态）    │    │
│  │  └── tags_index{}     分类/标签索引        │    │
│  └──────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────┐    │
│  │ covers/              (EMBED_FILES)         │    │
│  │  ├── miner_dashboard_thumb.png            │    │
│  │  └── ...              封面缩略图（可选）    │    │
│  └──────────────────────────────────────────┘    │
└──────────────────────────────────────────────────┘
         │
         ▼  运行时动态数据
┌──────────────────────────────────────────────────┐
│  FATFS 文件系统检查                                │
│  ├── /fatfs/skills/<id>/SKILL.md  存在 → 已安装    │
│  ├── /fatfs/ui/ui_page_4.lua      存在 → 自定义页   │
│  └── fatfs 剩余空间 → 容量指示器                    │
└──────────────────────────────────────────────────┘
```

### 2.2 数据结构

```c
// 技能卡片（运行时合并静态元数据 + 动态安装状态）
typedef struct {
    char id[64];             // "miner_dashboard"
    char title[64];          // "Miner Dashboard"
    char description[256];   // 一句话描述
    char author[64];         // 作者
    uint32_t total_size;     // 总大小 (bytes)
    bool featured;           // 是否精选
    uint8_t category;        // CAT_MINING / CAT_GAME / CAT_UTILITY / CAT_AI
    // 运行时状态
    bool installed;          // FATFS 检测结果
    uint8_t install_state;   // INSTALL_NONE / DOWNLOADING / INSTALLING / INSTALLED
    uint8_t download_progress; // 0-100
} skill_card_t;

// 分类枚举
typedef enum {
    CAT_ALL = 0,
    CAT_MINING,
    CAT_GAME,
    CAT_UTILITY,
    CAT_AI,
    CAT_MY,        // "我的" — 已安装 + 自定义页面
    CAT_COUNT
} category_t;

// 自定义页面条目
typedef struct {
    uint8_t page_id;         // 4-7
    char name[64];           // 从文件名提取
    uint32_t size;           // 文件大小
    bool active;             // 是否激活（文件存在）
} custom_page_t;
```

---

## 3. 页面布局

### 3.1 整体结构

```
┌──────────────────────────────────────┐  y=0
│  🔨 Hammer Skills Lab                │  ← 顶部栏 h=58
│  ─────────────────────────────────── │
│  [全部][⛏挖矿][🎮游戏][🔧工具][🤖AI][📄我的]│  ← 分类标签 h=44
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 📦 封面(80x80)                 │  │
│  │                                │  │  ← 技能卡片 h=100
│  │ Miner Dashboard                │  │     可滚动列表
│  │ 实时算力/温度/收益面板          │  │
│  │ 18.5 KB      [安装 →]          │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ 🎮 封面                         │  │
│  │ Flappy Bird                    │  │
│  │ 经典小鸟飞行游戏                │  │
│  │ 18.7 KB      [✅ 已安装]        │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ ...                            │  │  ← 更多卡片...
│  └────────────────────────────────┘  │
│                                      │
│  ─────────────────────────────────── │
│  可用空间: ████████░░ 8.2MB/10MB     │  ← 容量指示器 h=36
│  [主页][设置][网络][自定义][🛒市场]    │  ← 底部栏 h=58
└──────────────────────────────────────┘  y=1280
```

### 3.2 卡片布局细节

```
┌──────────────────────────────────────────────┐
│ ┌────────┐                                   │
│ │        │  Miner Dashboard          ⛏ 精选   │  ← 标题 + 精选标签
│ │  COVER │  实时算力/温度/收益面板             │  ← 描述 (2行)
│ │  80x80 │  作者: HammerMiner                │  ← 作者
│ │        │  18.5 KB          [ 安装 → ]      │  ← 大小 + 按钮
│ └────────┘                                   │
└──────────────────────────────────────────────┘

按钮状态:
  [ 安装 → ]     灰色底 + 蓝色箭头     ← 未安装
  [ ⏳ 下载中 ]   橙色底 + 进度条       ← 正在下载
  [ ✅ 已安装 ]   绿色底 + 勾           ← 已安装（点击可卸载）
  [ ❌ 空间不足 ] 红色底               ← 空间不够
```

### 3.3 "📄 我的" 标签页布局

```
┌──────────────────────────────────────┐
│  已安装技能                           │
│  ┌────────────────────────────────┐  │
│  │ Miner Dashboard   ✅ 已安装    │  │
│  │ 18.5 KB          [卸载]       │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ Flappy Bird       ✅ 已安装    │  │
│  │ 18.7 KB          [卸载]       │  │
│  └────────────────────────────────┘  │
│                                      │
│  自定义页面                           │
│  ┌────────────────────────────────┐  │
│  │ Page 4: 扫雷                   │  │
│  │ /fatfs/ui/ui_page_4.lua       │  │
│  │ 5.2 KB          [▶ 预览]      │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ Page 5: 日历                   │  │
│  │ /fatfs/ui/ui_page_5.lua       │  │
│  │ 8.1 KB          [▶ 预览]      │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ [+ 新建自定义页面...]           │  │  ← 跳转到 WebIM 让 AI 生成
│  └────────────────────────────────┘  │
│                                      │
│  可用空间: ████████░░ 8.2MB/10MB     │
└──────────────────────────────────────┘
```

---

## 4. 状态机

### 4.1 技能安装状态机

```
                    ┌─────────┐
        进入详情页    │  IDLE   │
       ┌───────────→│         │←──────────┐
       │            └────┬────┘           │
       │                 │ 点击[安装]       │ 空间不足/失败
       │                 ▼                 │
       │            ┌─────────┐           │
       │            │ SPACE   │─────→ 弹窗提示
       │            │ _CHECK  │      "空间不足，需 X MB"
       │            └────┬────┘           │
       │             空间足够 │              │
       │                 ▼                 │
       │            ┌─────────┐           │
       │  进度条刷新  │DOWNLOAD │           │
       │  ←────────│ _ING    │           │
       │            └────┬────┘           │
       │             下载完成│              │
       │                 ▼                 │
       │            ┌─────────┐   失败     │
       │            │INSTALL  │───────────┘
       │            │ _ING    │
       │            └────┬────┘
       │             写入完成│
       │                 ▼
       │            ┌─────────┐
       │            │INSTALLED│  点击[卸载]
       └───────────│         │──────────→ 弹窗确认 → 删除文件 → IDLE
                    └─────────┘
```

### 4.2 空间检查逻辑

```c
// 伪代码
esp_err_t check_space_before_install(skill_card_t *skill) {
    uint64_t free_kb = fatfs_get_free_space("/fatfs");
    uint64_t need_kb = skill->total_size / 1024 + 256;  // +256KB 安全余量

    if (free_kb < need_kb) {
        char msg[128];
        snprintf(msg, sizeof(msg),
            "空间不足！\n需要: %llu KB\n可用: %llu KB\n请卸载其他技能后重试",
            need_kb, free_kb);
        show_dialog("空间不足", msg, DIALOG_OK);
        return ESP_ERR_NO_MEM;
    }
    return ESP_OK;
}
```

---

## 5. 封面图片策略

### 5.1 三级方案

| 级别 | 来源 | 优点 | 缺点 |
|------|------|------|------|
| **A 级** | 技能自带 `assets/cover.png`，编译进 skills-data.json (base64) 或单独嵌入 | 离线可用，零网络延迟 | 固件体积增大 |
| **B 级** | GitHub raw 懒加载，首次浏览时下载并缓存到 `/fatfs/cache/` | 不占固件体积 | 首次加载慢，需网络 |
| **C 级** | 按分类生成色块 + 图标文字（兜底） | 零依赖 | 不够"炫酷" |

### 5.2 推荐方案：B 级为主 + C 级兜底

```
首次打开技能市场:
  ① 显示 C 级占位（分类色块 + emoji 图标）
  ② 后台异步下载封面 PNG (60x60 或 80x80)
  ③ 下载完成后替换占位图
  ④ 缓存到 /fatfs/cache/covers/<skill_id>.png
  
再次打开:
  ① 先检查缓存，有则直接显示
  ② 缓存未命中才走网络
```

### 5.3 封面规格

```
尺寸: 80x80 px
格式: PNG (RGBA8888, 需 lodepng 解码 — BC08 已支持)
大小: < 5KB/张
缓存路径: /fatfs/cache/covers/<skill_id>.png
最大缓存: 32 张 (≈160KB)
```

---

## 6. 存储空间管理

### 6.1 分区容量

```
FATFS (esp_claw 分区): 2MB (0x200000 bytes)
├── skills/         ← 已安装技能
├── ui/             ← 自定义页面 Lua 脚本
├── sessions/       ← 聊天记录
├── memory/         ← AI 记忆
├── cache/          ← 封面缓存
├── router_rules/   ← 事件路由
├── scheduler/      ← 定时任务
└── scripts/        ← 其他 Lua 脚本
```

### 6.2 容量指示器算法

```c
#define FATFS_TOTAL_KB  (2 * 1024)  // 2MB

void update_space_indicator(lv_obj_t *bar, lv_obj_t *label) {
    uint64_t free_bytes = fatfs_get_free_space("/fatfs");
    uint64_t used_kb = FATFS_TOTAL_KB - (free_bytes / 1024);
    
    lv_bar_set_value(bar, (int)(used_kb * 100 / FATFS_TOTAL_KB), LV_ANIM_ON);
    lv_label_set_text_fmt(label, "可用: %llu KB / %d KB", 
                          free_bytes / 1024, FATFS_TOTAL_KB);
    
    // 低于 256KB 变红警告
    if (free_bytes < 256 * 1024) {
        lv_obj_set_style_bg_color(bar, lv_color_hex(0xFF4444), LV_PART_INDICATOR);
    }
}
```

---

## 7. 自定义页面区域（📄 我的）

### 7.1 与技能存储分离

```
/fatfs/
├── skills/              ← 技能安装目录（skills_lab_downloader 管理）
│   ├── flappybird/
│   └── miner_dashboard/
│
└── ui/                  ← 自定义页面目录（AI 生成 + 用户编辑）
    ├── ui_page_4.lua    ← 扫雷
    ├── ui_page_5.lua    ← 日历
    ├── ui_page_6.lua    ← 图片
    └── ui_page_7.lua    ← 保留（不可用于自定义，是技能市场）
```

### 7.2 新建自定义页面流程

```
用户 → 点击 [+ 新建自定义页面]
     → 弹出输入框："描述你想要的页面..."
     → 后台调 WebIM → LLM 生成 Lua 代码
     → LLM 写 /fatfs/ui/ui_page_X.lua
     → 写入完成后自动刷新页面列表
     → 用户可点击 [▶ 预览] 跳转到该页面
```

### 7.3 自定义页面元数据

在对应 Lua 脚本头部约定注释格式：

```lua
-- @name 算力仪表盘
-- @desc 实时显示算力曲线、温度、风扇转速
-- @author 用户
-- @version 1.0
-- @icon hashrate
```

技能市场解析这些注释来展示自定义页面的名称、描述。

### 7.4 自定义页面管理

```
功能:
  [▶ 预览]     → claw.display.change_page(page_id)
  [✏ 编辑]     → 跳转 WebIM，告诉 LLM "修改 page X"
  [🗑 删除]     → 确认弹窗 → unlink(/fatfs/ui/ui_page_X.lua)
  [📋 查看源码] → 跳转 WebIM，显示文件内容
```

---

## 8. 下载/安装/卸载的具体实现

### 8.1 下载流程

```
① 用户点击 [安装]
② 空间检查（check_space_before_install）
③ 卡片状态 → DOWNLOADING，显示进度条
④ 调 skills_lab_downloader 的 Lua 脚本（异步）:
   cap_lua_async → download_skill.lua action=install
⑤ 轮询 job 状态 + 解析日志输出获取进度
⑥ 完成 → 状态变 INSTALLED
⑦ 刷新容量指示器
⑧ 如果 "📄 我的" 标签页打开，刷新列表
```

### 8.2 卸载流程

```
① 用户长按已安装卡片（或点击 [卸载] 按钮）
② 弹窗确认："确定要卸载 Miner Dashboard 吗？"
   [确认] [取消]
③ 递归删除 /fatfs/skills/<id>/
④ 调用 unregister_skill（从 LLM 技能列表移除）
⑤ 卡片状态 → IDLE
⑥ 刷新容量指示器
```

### 8.3 安装/卸载 API 需求（C 层）

```c
// 安装技能（异步，返回 job_id 用于轮询）
esp_err_t skill_market_install(const char *skill_id, 
                                char *job_id_out, size_t job_id_size);

// 查询安装进度
esp_err_t skill_market_get_progress(const char *job_id,
                                     uint8_t *progress_out,
                                     char *status_out, size_t status_size);

// 卸载技能
esp_err_t skill_market_uninstall(const char *skill_id);

// 检查是否已安装
bool skill_market_is_installed(const char *skill_id);

// 获取 FATFS 可用空间
uint64_t skill_market_get_free_space(void);
```

---

## 9. API 需求汇总

### 9.1 需要新增的 LVGL API（C 层提供，Lua 可调）

| API | 说明 | 优先级 |
|-----|------|--------|
| `claw.display.update_label(id, text)` | 更新已有文本 | **Phase 1** |
| `claw.display.update_bar(id, value)` | 更新已有进度条 | **Phase 1** |
| `claw.display.delete(id)` | 删除 UI 元素 | **Phase 1** |
| `claw.display.sleep(ms)` | 非阻塞延迟 | **Phase 1** |
| `claw.display.peek_event()` | 非阻塞事件检测 | Phase 2 |
| `claw.display.image(x, y, path)` | 显示 PNG 图片 | Phase 2 |

### 9.2 技能市场专有 C 接口

| 接口 | 来源 | 说明 |
|------|------|------|
| `skills-data.json` | 编译时嵌入 | 技能目录元数据 |
| `cap_lua_async_submit()` | cap_lua | 异步执行安装 Lua 脚本 |
| `cap_lua_async_get_status()` | cap_lua | 查询安装进度 |
| `fatfs_get_free_space()` | FATFS | 空间检查 |
| `unlink()` / `rmdir_r()` | POSIX | 卸载时删除文件 |
| `claw_skill_unregister()` | cap_skill_mgr | 从 LLM 技能列表移除 |

---

## 10. 文件清单（实现时需要创建/修改）

```
新增文件:
  main/tasks/skill_market_page.c       ← 技能市场 LVGL 页面主体
  main/tasks/skill_market_page.h
  main/tasks/skill_market_installer.c  ← 安装/卸载/空间管理
  main/tasks/skill_market_installer.h
  components/esp_claw/.../skills-data.json  ← 编译时嵌入的技能目录

修改文件:
  main/lvgl_screen.c                   ← 注册 Page 7 + 底部栏图标
  main/http_server/...                 ← 可能需要在 Web 端显示技能状态
  components/esp_claw/.../cap_lua      ← peek_event + sleep + update_* API
```

---

## 11. 分期规划

### Phase 2a — 核心功能（1-2 周）

- [x] 规划文档（本文）
- [ ] `skills-data.json` 生成脚本 + 固件嵌入
- [ ] 卡片列表渲染（分类筛选 + 滚动）
- [ ] 安装/卸载按钮 + FATFS 状态检测
- [ ] 容量指示器
- [ ] 空间不足弹窗

### Phase 2b — 视觉增强（1 周）

- [ ] 封面图片异步下载 + 缓存
- [ ] 安装进度条
- [ ] 下载失败重试

### Phase 2c — 自定义页面（1 周）

- [ ] "📄 我的" 标签页
- [ ] 自定义页面列表 + 预览/删除
- [ ] 新建自定义页面 → LLM 生成

### Phase 2d — Lua API 补全（Phase 1 先行）

- [ ] `update_label` / `update_bar` / `delete` / `sleep`
- [ ] `peek_event` / `image`

---

*规划版本: v1.0 · 2026-06-12*
