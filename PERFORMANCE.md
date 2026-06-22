# FSD_Cangjie 功能与性能报告

## 仓颉 vs C 版性能对比

### 架构差异

| 维度 | C 版 (fsd-master) | 仓颉版 (FSD_Cangjie) |
|------|------------------|---------------------|
| **数据结构** | 单向链表 O(n) | HashMap O(1) |
| **并发模型** | 单线程 select | spawn 多线程 |
| **客户端查找** | 每次从头遍历 | 哈希直接定位 |
| **CID 查找** | 不支持（需遍历） | 独立 cidIndex 索引 |
| **内存管理** | 手动 malloc/free | GC 自动回收 |
| **语言安全** | 指针裸操作，易崩溃 | 类型安全，无野指针 |

### 基准测试结果

测试条件：500 个在线客户端，各执行 10,000 次操作取平均。

#### 测试 1：按呼号查找 `getClient(callsign)`

| 版本 | 数据结构 | 总耗时 | 平均每次 | 加速比 |
|------|---------|--------|---------|-------|
| C 版 | 链表遍历 | 208.63 ms | 20.86 µs | 1x |
| 仓颉 | HashMap | **1.43 ms** | **0.14 µs** | **146x** |

#### 测试 2：按 CID 查找 `getClientByCid(cid)`

| 版本 | 数据结构 | 总耗时 | 平均每次 | 加速比 |
|------|---------|--------|---------|-------|
| C 版 | 链表遍历 | 74.20 ms | 7.42 µs | 1x |
| 仓颉 | HashMap(双索引) | **1.33 ms** | **0.13 µs** | **56x** |

#### 测试 3：混合操作（50% 查找 + 25% 添加 + 25% 删除）

| 版本 | 总耗时 | 加速比 |
|------|--------|-------|
| C 版 | 455.92 ms | 1x |
| 仓颉 | **2.66 ms** | **171x** |

### 关键改动

#### 1. 客户端存储：链表 → HashMap

**client.cj**
```
- var rootClient: ?Client = None          // C 版单向链表
+ var clientMap = HashMap<String, Client>() // 仓颉哈希表
+ var cidIndex = HashMap<String, String>()  // CID→呼号索引
```

#### 2. 查找函数：O(n) → O(1)

```cangjie
// 旧：遍历链表 O(n)
func getClient(callsign: String): ?Client {
    let upperCs = callsign.toUpper()
    var cur = rootClient
    while (true) {
        match (cur) {
            case Some(cl) =>
                if (cl.callsign.toUpper() == upperCs) { return cur }
                cur = cl.next
            case None => break
        }
    }
    return None
}

// 新：HashMap O(1)
func getClient(callsign: String): ?Client {
    return clientMap.get(callsign.toUpper())
}
```

---

## 功能清单

### 已实现 ✅

#### 客户端协议
| 功能 | 说明 |
|------|------|
| #AA/#AP 登录 | ATC/飞行员登录，含呼号查重 + CID 唯一性 + OBS 豁免 |
| #DA/#DP 登出 | 登出广播 + 统计记录 |
| @/% 位置更新 | 飞行员/ATC 位置广播 |
| $FP 飞行计划 | 提交/同步/广播 |
| #TM 文字消息 | 单发、全体、频率隔离（@122.800 同频转发） |
| $HO/$HA 管制移交 | 移交请求/接受 |
| $C?/$CI 通信请求 | 点对点通信 |
| $AX ACARS | 航空器通信寻址与报告系统 |
| $CQ 查询/RN 回复 | 呼号查询与实名回复 |
| #PC 飞行员命令 | 飞行员指令转发 |
| #WX 天气请求 | METAR 实时查询 |
| #CD/#WD/#TD/#DL 天气数据 | 风/云/温度/散度数据广播 |
| $!! 踢出 | 管理员踢人 |
| #SB 语音服务 | 原始字节透传（支持语音） |

#### 服务端功能
| 功能 | 说明 |
|------|------|
| MySQL 认证 | 用户验证 + 飞行计划存储，回退 cert.txt |
| 禁止航班号 | blocked_flights 配置 + 热重载 |
| HTTP API | REST 接口（状态/飞行计划 CRUD） |
| 语音中继 | Voice server 独立 TCP 6808 |
| 系统管理 | telnet 端口完整命令（servers/clients/kill/log 等） |
| 配置热重载 | fsd.conf 修改后 10 秒自动重新加载 |
| 飞行回放 | 位置数据记入 replay_YYYYMMDD.txt |
| 连飞统计 | 连线时长记录到 stats.txt |

#### 多服务器互联
| 功能 | 说明 |
|------|------|
| NOTIFY 路由 | 服务器间自动发现 + 路由表同步 |
| 客户端同步 | ADDCLIENT/RMCLIENT 跨服务器传播 |
| 位置同步 | PD/AD 位置数据跨服务器广播 |
| 飞行计划同步 | PLAN 跨服务器传播 |
| 证书同步 | CERT_ADD/DELETE/MODIFY 跨服务器 |
| 自动重连 | connectLoop 30 秒轮询重连 |
| NOTIFY 路径追踪 | 路由表记录 via/hops |
| LINKDOWN 清理 | 断开服务器时自动清理路由 |

#### 安全性
| 功能 | 说明 |
|------|------|
| CID 唯一性 | 同一 CID 不能重复登录（OBS 豁免） |
| 呼号大小写不敏感 | getClient/addClient 统一 toUpper |
| 洪水防护 | 连接级 floodLimit |
| IP 白名单框架 | allowfrom 配置读取 + checkPeer 钩子就绪 |
| 竞态防护 | addClient 二次查重防止 race condition |

---

## Bug 修复记录

### 2026-06-22 多服务器互联 Bug 清单

| # | Bug | 文件 | 修复 |
|---|-----|------|------|
| 1 | `connectLoop` 没调 `serve()` 处理远程数据 | `servinterface.cj` | 连接后调 `serve(user)` |
| 2 | `createUser` 没把用户加到 `this.users` | `servinterface.cj` | 加 `this.users.add(u)` |
| 3 | `sendFeed()` 在用户加进列表前就调用 | `servinterface.cj` | 移到 `createUser` 里加完再调 |
| 4 | `sendFeed()` 没发自己的 NOTIFY | `servinterface.cj` | 先发 `myServer` 的 NOTIFY |
| 5 | `serve()` 先读后写导致数据发不出去 | `netbase.cj` | `serve()` 开始先 flush `outStr` |
| 6 | NOTIFY 字段偏移（parts[5]→parts[6]） | `servinterface.cj` | 数据从 `parts[5]` 开始 |
| 7 | 全部 execCmd 字段偏移错误 | `servinterface.cj` | ADDCLIENT/PD/AD/PLAN/CERT 等 +1 修正 |

### ECHO 错误提示修复

| 问题 | 修复 |
|------|------|
| 同呼号重复登录显示"无法访问" | 改为 `ERR_CSINUSE`(1) → "呼号已被使用" |
| 禁止航班号显示"账号被封禁" | 改为 `ERR_NOSUCHCS`(7) → "无法访问到该呼号" |
| `$ER` 格式不匹配 C 版 | env 传空、callsign 传 "unknown" |
| 检查顺序反了 | callsign 先于 protocol 检查 |
| `sendError` 缓冲再写导致丢失 | 改为直接 `socket.write()` |

---

## 与 C 版的差距（备忘录）

详见 `memory/todo_vs_c_version.md`。

主要未实现：
- IP 白名单 `allowfrom`（等 Cangjie `TcpSocket.remoteAddress` API）
- `$PI`/`$PO` 客户端 ping/pong
- `delguard` 命令
- 服务器路由路径追踪（当前简化为 broadcast）
- 天气配置管理 `wp create/delete/activate/set`
