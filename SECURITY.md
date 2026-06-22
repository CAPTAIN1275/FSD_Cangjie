# FSD_Cangjie 安全审计报告

> 审计日期: 2026-06-22 | 代码库: d:\Desktop\FSD_Cangjie\src\

---

## 已修复 ✅

| # | 问题 | 严重 | 文件 | 修复内容 |
|---|------|------|------|---------|
| 1 | PHP 命令注入 | 🔴 | mysqldb.cj | `$argv` 传参替代代码拼接 |
| 2 | HTTP API 无认证 | 🔴 | httpapi.cj, fsd.cj | 添加 `?key=xxx` 验证 |
| 3 | MAX_CLIENTS 无上限 | 🟡 | client.cj | `addClient()` 超 500 拒 |
| 4 | 洪水阈值过高 | 🟡 | fsd.cj | 100000→50000 |
| 5 | ICAO 无验证 → SSRF | 🟡 | metar.cj | 只允许 2-4 位字母 |
| 6 | shutdown 无确认 | 🟡 | sysinterface.cj | 需 `shutdown confirm` |
| 7 | 忙等循环空转 CPU | 🟢 | clinterface.cj | `for 100M` → `sleep(50ms)` |
| 8 | KILL 无审计 | 🟡 | servinterface.cj | 加日志记录来源(KILL偏移bug一并修复) |
| 9 | whazzup 写入太快 | 🟢 | global.cj | 改回 2 秒 |
| 10 | clientMap/cidIndex 无锁 | 🔴 | client.cj | Mutex 保护所有读写 + getClientKeys() 快照遍历 |
| 11 | rootCert 链表无锁 | 🔴 | certificate.cj | certLock Mutex 保护所有增删查 |
| 12 | rootServer 链表无锁 | 🔴 | server.cj | serverLock Mutex 保护所有增删查 |
| 13 | replayBuf 竞态 | 🔴 | fsd.cj, clinterface.cj | replayLock Mutex 保护读写 |
| 14 | 端口号无范围验证 | 🔴 | fsd.cj | gPort + httpapi port 加入 1-65535 校验 |
| 15 | 心跳 URL 主机名注入 | 🟡 | fsd.cj | 去除 &?# 和空格 |
| 16 | parseInt32/64 溢出崩溃 | 🟡 | extensions.cj | 溢出前检查，超限返回 MAX |
| 17 | 语音帧长度无上限 | 🟡 | voice_server.cj | frameLen > 65536 清空断开 |
| 18 | JSON 响应未转义 | 🟡 | httpapi.cj | fp_data 中的 "\\\n\r\t 转义 |
| 19 | 系统端口密码暴破 | 🟡 | sysinterface.cj | 密码错误加 1 秒延迟 |
| 20 | stats.txt 竞争条件 | 🟢 | clinterface.cj | statsLock Mutex 保护 |
| 21 | 主循环无异常保护 | 🟢 | main.cj | try-catch 包裹 engine.run() |
| 22 | replayBuf 无大小限制 | 🟢 | clinterface.cj | 限制最大 1MB |
| 23 | KILL 来源不可信 | 🟡 | servinterface.cj | 仅接受已知服务器的 KILL |
| 24 | 证书同步来源不可信 | 🟡 | servinterface.cj | 仅接受已知服务器的 CERT |
| 25 | API 密钥 URL 明文传输 | 🟡 | httpapi.cj | 同时支持 Authorization: Bearer 头 |
| 26 | 语音 JSON 解析缺陷 | 🟢 | voice_server.cj | 支持空格/转义引号/值限长 512 |

---

## 🔴 严重（未修复）

（已全部修复 ✅）

---

## 🟡 中危（未修复）

### #15 — 密码明文存储与传输
- **文件**: cert.txt / certificate.cj / mysqldb.cj
- **说明**: cert.txt 明文密码，MySQL 明文传输（用户确认不修）

### #16 — 系统端口权限提升
- **文件**: sysinterface.cj
- **说明**: pwd 登录后可 shutdown/kill/cert 等高危操作

### #17 — 服务器间 KILL 伪造
- **文件**: servinterface.cj
- **说明**: 收到 KILL 无条件踢人，无签名验证

### #18 — stats.txt 竞争条件
- **文件**: clinterface.cj:658-659
- **说明**: 读-改-写非原子，高并发丢数据

### #19 — 证书同步无信任
- **文件**: servinterface.cj
- **说明**: CERT_ADD 无条件信任对端

### #20 — 心跳 URL 未转义主机名
- **文件**: fsd.cj
- **说明**: hostname 拼入 URL 可能被污染

### #21 — HTTP API 密钥 URL 明文传输
- **文件**: httpapi.cj
- **说明**: `?key=xxx` 出现在访问日志/浏览器历史

### #22 — JSON 响应未转义用户数据
- **文件**: httpapi.cj
- **说明**: fp_data 含 `"` 破坏 JSON 结构

### #23 — 语音 JSON 解析器缺陷
- **文件**: voice_server.cj
- **说明**: 不支持转义引号，解析提前结束

### #24 — 语音帧长度无上限
- **文件**: voice_server.cj
- **说明**: frameLen 可导致溢出/panic

### #25 — parseInt32/parseInt64 无溢出保护
- **文件**: extensions.cj
- **说明**: 超 INT32_MAX 触发 panic

### #26 — IP 白名单完全失效
- **文件**: clinterface.cj / servinterface.cj
- **说明**: checkPeer() 直接 return true

### #27 — 客户端连接数无上限（已修 #3）

---

## 🟢 低危（未修复）

### #28 — 日志记录敏感信息
- **文件**: 多处 dolog()
- **说明**: 密码验证结果、认证详情在 DEBUG 日志中

### #29 — 配置热重载无原子性
- **文件**: config.cj
- **说明**: 半写配置可能被其他线程读到

### #30 — 主循环无异常保护
- **文件**: main.cj
- **说明**: engine.run() 抛出异常直接崩溃

### #31 — replayBuf 无大小限制 → OOM
- **文件**: fsd.cj
- **说明**: 刷盘失败时无限增长

### #32 — 链表遍历无深度保护
- **文件**: certificate.cj
- **说明**: 链表成环时死循环

### #33 — 配置热重载不验证字段完整性
- **文件**: config.cj
- **说明**: 部分写入的配置导致端口/安全配置被清空

### #34 — 风数据广播可能 DoS
- **文件**: fsd.cj
- **说明**: 500 客户端 × 500 消息 = 25 万条/70秒

---

## ℹ️ 建议

### #35 — cert.txt 示例密码过于简单
- **说明**: 4 个管理员账号密码均为 "1275"

### #36 — 自实现三角函数精度有限
- **说明**: 3 阶泰勒展开在大角度时精度不足

### #37 — 随机数 LCG 可预测
- **说明**: 种子基于秒级时间
