# BC08 Lua Simulator 沙箱与安全设计文档

> 目标：保证 Skill 卡 Lua 脚本在模拟器中安全运行，防止死循环、异常调用、网络滥用等问题影响浏览器主线程或用户数据。

---

## 1. 威胁模型

Skill 卡脚本由第三方或客户编写，可能存在以下风险：

| 风险 | 示例 | 影响 |
|------|------|------|
| 死循环 /  busy loop | `while true do end` | 卡住浏览器，UI 无响应 |
| 高频轮询 | `while true do net.get(...) end` | 发起大量请求，刷爆接口/内存 |
| 非法 API 调用 | `claw.display.button(1, nil, -100, -100, 1e9, 1e9, "x", "red")` | 渲染异常或崩溃 |
| 网络滥用 | 访问内网、未授权域名、http 明文接口 | 泄露信息、绕过 CORS |
| 内存泄漏 | 无限创建页面 / 控件 / 大字符串 | 内存持续增长 |
| 原生 JS 逃逸 | 通过 `js` 全局对象访问 `window` | 理论上目前被 Fengari 控制，但仍需警惕 |
| 脚本加载错误 | 语法错误、引用未定义 API | 运行时崩溃，调试信息混乱 |

---

## 2. 当前实现状态

当前模拟器已实现：

- 基于 [Fengari](https://github.com/fengari-lua/fengari) 的 Lua 5.3 运行时
- 脚本以协程方式运行，`delay.delay_ms()` 内部 `lua_yieldk` 让出
- 运行时状态机：`running` / `stopped`
- `RUN_TIMEOUT_MS = Number.POSITIVE_INFINITY`（当前已禁用超时，由用户手动 Stop/Reset）
- `netFetch` 白名单 `allowedHosts` + 协议校验
- `lua_atnativeerror` 捕获 JS 层异常
- 停止时清理 timer、Lua state、页面和事件队列

当前仍缺失：

- 无 Lua 执行步数/指令限制
- 无运行时超时（用户已要求去掉 30s 限制）
- 无内存用量限制
- API 参数校验较弱
- 单帧内连续调用 API 无限制
- 无显式沙箱白名单机制

---

## 3. 设计目标

1. **用户可控**：脚本可长期运行，但用户随时能 Stop/Reset。
2. **浏览器不卡死**：即使脚本有死循环，也不能阻塞主线程。
3. **API 安全**：参数类型、范围、数量必须校验，拒绝明显非法输入。
4. **网络受限**：只能访问明确允许的域名/协议，防止滥用。
5. **资源有上限**：控件数、页面数、网络并发、日志条数必须受控。
6. **错误可观测**：运行时错误、API 调用错误、网络错误必须输出到 Debug Log。
7. **状态隔离**：Stop/Reset 必须彻底清除 Lua state、timer、网络请求、事件队列。

---

## 4. 沙箱策略

### 4.1 Lua 环境隔离

Fengari 默认会注入 `js` 全局模块，允许 Lua 调用 JS。当前已注册 `interop.luaopen_js` 但不在全局暴露危险函数。

建议：

- 不将 `window`、`document`、`fetch` 等注入 Lua 全局。
- 仅暴露白名单 API：`claw.display`、`claw.rgb`、`delay`、`net`、`sys`、`storage`。
- 运行前清空全局环境中除标准库必要函数外的无关内容（可选）。

### 4.2 API 调用校验

每个 API 在实现层必须校验：

| API | 校验项 |
|-----|--------|
| `claw.display.create_page` | `page_id` 为数字；`title` 可转字符串 |
| `claw.display.button/label/container/image` | 坐标/宽高为数字且在 `0 ~ 1e5` 范围；`page_id` 存在；颜色为数字 |
| `claw.display.image` | `path` 为字符串，禁止 `..` 越界访问或绝对路径（模拟器按规则映射） |
| `claw.rgb.set/set_zone` | 颜色为 `0 ~ 0xFFFFFF` 整数；zone 索引 `1~4` |
| `claw.rgb.effect` | effect name 为字符串，仅允许预定义效果名 |
| `delay.delay_ms` | 非负数字，上限 60,000 ms（1 分钟） |
| `net.*` | URL 协议、域名白名单、请求频率限制 |
| `sys.log` | level 必须是 `debug/info/warn/error` 之一 |
| `storage.*` | 路径字符串，禁止访问父目录 `..` |

校验失败时：

- 向 Debug Log 输出 `warn` 级别错误，说明参数非法。
- 忽略本次调用，不抛出异常导致脚本中断（避免恶意脚本通过故意报错结束运行）。
- 可选：累计错误次数超过阈值后自动 Stop。

### 4.3 资源上限

| 资源 | 建议上限 | 行为 |
|------|---------|------|
| 页面数 | 16 | 超出时删除最早页面或拒绝创建 |
| 单页控件数 | 256 | 超出时拒绝添加 |
| 单帧 API 调用次数 | 1000 | 超过则 yield 到下一帧，防止单帧卡死 |
| 图片缓存 | 64 张 | LRU 淘汰 |
| 网络并发 | 6 | 超出排队 |
| 网络请求最小间隔 | 1000 ms（同 URL） | 拒绝或返回缓存 |
| Debug Log | 500 条 | 滚动保留 |
| 单字符串/表大小 | 1 MB | 拒绝写入 |

### 4.4 运行时不卡死

当前已使用协程 + `delay.delay_ms` yield，因此纯 Lua 死循环不会阻塞主线程，因为脚本必须调用 `delay.delay_ms` 才会继续执行。但如果脚本：

```lua
while true do
    claw.display.label(1, 1, 0, 0, "x", 0xFFFFFF, 20)
end
```

会在单帧内无限创建控件，导致主线程卡顿。

解决方案：

- **单帧 API 调用计数器**：每帧累计 API 调用次数，超过阈值后强制 `lua_yieldk(0)`，让出主线程。
- **每帧执行时间片**：记录单次 `doResume()` 耗时，超过 16 ms 则 yield，保证 60 FPS。

### 4.5 超时策略

当前 `RUN_TIMEOUT_MS = Number.POSITIVE_INFINITY`，由用户手动 Stop。

保留现状，但补充：

- 在 UI 上明确提示“脚本无超时，请手动 Stop/Reset”。
- 提供“强制停止”按钮（已实现）。
- 如果未来需要自动保护，可增加可选的“最大运行时间”设置（默认关闭）。

### 4.6 网络沙箱

当前已支持 `allowedHosts` 白名单，但默认空数组表示全部放行。

建议默认策略：

```js
allowedHosts: [
  'mempool.space',
  'api.coingecko.com',
  'api.blockchair.com',
  'api.blockcypher.com',
]
```

并强化：

- 仅允许 `https:` 协议。
- 对 `localhost`、`127.0.0.1`、内网 IP 默认拒绝。
- 每个域名并发请求限制为 3。
- 同一 URL 1 秒内最多请求 1 次（可配置）。

---

## 5. 错误处理设计

### 5.1 错误分类

| 阶段 | 错误类型 | 处理方式 |
|------|---------|---------|
| 加载阶段 | 语法错误、无法解析 | `luaL_loadstring` 失败 → Debug Log 输出 `Load error` → Stop |
| 运行阶段 | Lua 运行时错误 | `lua_resume` 非 OK/YIELD → Debug Log 输出 `Runtime error` → Stop |
| JS 层异常 | API 内部抛错 | `lua_atnativeerror` 捕获 → Debug Log 输出 `Native error` → Stop |
| API 参数非法 | 类型/范围/数量错误 | Debug Log 输出 `API warn` → 忽略调用 → 继续运行 |
| 网络错误 | fetch 失败、超时、被拦截 | 回调 `status=0, body=错误信息` → 脚本自行处理 |
| 回调错误 | Lua 回调函数内部抛错 | `lua_pcall` 捕获 → Debug Log 输出 `Callback error` → 继续运行 |

### 5.2 错误提示规范

所有错误日志统一格式：

```
[HH:MM:SS] Load error: unexpected symbol near '...'
[HH:MM:SS] Runtime error (2, type=4): attempt to call a nil value (global 'foo')
[HH:MM:SS] Native error: TypeError: Cannot read properties of undefined
[HH:MM:SS] API warn [claw.display.button]: page_id must be a number
[HH:MM:SS] Network error: Host not allowed: evil.com
```

---

## 6. 资源清理

`LuaRuntime.stop()` 必须保证：

1. `this.running = false`
2. 清除 `this.timer`
3. `this.L = null; this.co = null`（释放 Lua state）
4. 清空 `this.eventQueue`
5. 清空 `this.pages`
6. 重置 `this.rgbState`
7. 中断所有进行中的 `fetch`（保留 AbortController 列表，stop 时全部 abort）
8. 调用 `onStateChange('stopped')`

`reset` 时除了 stop 还需要清空 Debug Log（由 UI 层处理）。

---

## 7. 建议实现清单

按优先级排序：

1. **API 参数校验层**：在 `clawDisplayApi.js`、`clawRgbApi.js` 中加入统一校验函数，非法参数输出 warn 日志并忽略。
2. **单帧 API 调用上限**：在 `LuaRuntime` 中增加 `apiCallsThisFrame` 计数器，超过阈值时 yield。
3. **资源上限**：页面数、单页控件数、图片缓存数、日志条数限制。
4. **网络默认白名单 + 限流**：默认只允许常见公共 API，限制并发和最小间隔。
5. **fetch AbortController 清理**：运行时停止时取消所有未完成的网络请求。
6. **内存上限（可选）**：监控 Lua state 或 API 调用中创建的大字符串/表。
7. **可选运行时超时设置**：允许用户在 UI 中开启自动停止（默认关闭）。

---

## 8. 最小安全示例

一个符合规范的 Skill 脚本：

```lua
local PAGE = 1
local W, H = claw.display.get_size()

claw.display.create_page(PAGE, "Safe Demo")
claw.display.container(PAGE, 1, 0, 0, W, H, 0x000000, 0)
claw.display.label(PAGE, 2, W / 2 - 120, H / 2 - 20, "Hello!", 0x02FFB5, 36)
claw.display.button(PAGE, 10, W / 2 - 80, H / 2 + 60, 160, 60, "Tap me", 0xFFFFFF)

claw.rgb.set(0x02FFB5)

while true do
    local p, obj = claw.display.pop_event()
    if p and obj == 10 then
        sys.log("info", "button tapped")
        claw.rgb.set(0xFF0000)
    end
    delay.delay_ms(33)
end
```

---

## 9. 后续扩展

- Lua 语法静态检查（加载前用 luac/AST 做基础扫描）
- 沙箱白名单可配置界面
- 运行时性能面板：API 调用次数、网络请求数、Lua 内存占用
- 脚本签名与信任等级
