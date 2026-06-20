# FSD_Cangjie

基于**华为仓颉 (Cangjie)** 编程语言重写的 FSD (Flight Simulator Daemon) 飞行模拟通信服务器。

原项目为 FSD 2.x (C/C++)，[https://github.com/kuroneko/fsd](https://github.com/kuroneko/fsd) 本作品完整移植协议与功能，支持 ECHO Pilot Client、Swift、EuroScope 等客户端接入。

使用 FSD V3.000 draft 9 协议
## 目前可在以下平台运行

- Windows
- Linux

---

## 作者

**CAPTAIN 1275**

FSD_Cangjie (Flight Simulator Daemon Cangjie) 仓颉版发起人

---

## 性能对比 C 原版

| 指标 | C 原版 (select 单线程) | 仓颉版 (M:N 协程) |
|------|------------------------|---------------------|
| **并发模型** | select() 事件循环，单线程 | M:N 轻量线程，多核并行 |
| **客户端上限** | 受 FD_SETSIZE 限制 (~1024) | 受 ulimit 限制 (65535+) |
| **消息延迟** | 出队缓存批量发送 | sendTo 直写 socket，零缓冲 |
| **内存安全** | 手动 malloc/free，越界风险 | 全并发 GC，自动回收 |
| **CPU 利用** | 单核空转轮询 | 多核 work-stealing 调度 |
| **阻塞处理** | 一个阻塞拖垮全部 | 协程隔离，互不影响 |

## 相对于 C 原版的改进

| 项目 | C 原版 | 仓颉版 |
|------|--------|--------|
| **内存安全** | 手动 malloc/free | 全并发 GC |
| **字符串处理** | char[] + sprintf，溢出隐患 | String 原生 Unicode |
| **并发模型** | select() 单线程轮询 | M:N 轻量线程 |
| **协议解析** | strtok 破坏原字符串 | splitStr 无副作用 |
| **跨平台** | 两套 Makefile | cjpm 统一构建 |
| **代码量** | ~5000 行 C | ~2000 行仓颉 |

## 功能实现状态对比 C 原版

### ✅ 已实现

| 功能 | 文件 | 说明 |
|------|------|------|
| **客户端协议** | clinterface.cj | #AA/#AP 登录、#TM 消息（GBK/UTF8 透传）、$FP 飞行计划、@/% 位置、#WX 天气请求、$HO 移交、$!! 管理命令 |
| **服务端间协议** | servinterface.cj | 20 条 FSD 命令（NOTIFY/PING/PONG/SYNC/ADDCLIENT/RMCLIENT/PLAN/PD/AD/KILL 等） |
| **管理终端** | sysinterface.cj | help/time/quit/pwd/servers/clients/info/connect/ping/say/wall/kill/cert/route/stat/metar/weather/pos/log/distance/range/dump/wp |
| **WhazzUp 生成** | fsd.cj | 每 2 秒刷新 whazzup.txt（39 字段，含航向 pbh） |
| **METAR 天气** | metar.cj | 通过 curl 从 metar.vatsim.net 获取，15 分钟缓存 |
| **MySQL 数据库** | mysqldb.cj | 用户认证、飞行计划 CRUD、bcrypt 密码验证（PHP 中转） |
| **证书管理** | certificate.cj | cert.txt 加载、bcrypt/明文密码验证、等级系统 |
| **HTTP API** | httpapi.cj | 完整 REST 服务（GET /api/status、POST/GET/DELETE /api/flightplan）、CORS 支持 |
| **洪水防护** | netbase.cj | 每秒字节量限制 |
| **配置解析** | config.cj | fsd.conf 解析 |
| **网络层** | netbase.cj | TCP 监听/协程处理/读写缓冲 |
| **文本编码** | — | GBK 原始字节透传 + UTF-8 自动识别 |
| **连接统计** | clinterface.cj | stats.txt 记录，.stats 命令查询 |

### ❌ 当前版本暂未实现

| 功能 | 原因 |
|------|------|
| **IP 白名单 (ALLOW)** | 需要 `TcpSocket.getpeername()`，Cangjie 1.2.0+ 已有但本地是 1.1.0 |
| **GUARD 重连保护** | 同上（基于 IP 的防暴力重连） |
| **RBL IP 认证** | 同上，且 mcdu.com RBL 服务已下线 |

### 📌 无需移植

| 功能 | 原因 |
|------|------|
| **消息队列 (msgqueue)** | Cangjie M:N 协程天然异步，无需批量投递队列 |
| **统计变量 (manage)** | 使用 Cangjie 局部变量+日志代替 |
| **Windows 服务模式** | 仓颉版以普通进程运行，nohup/系统服务管理 |

---

## 快速使用

### 编译

```bash
cjpm build
```

### 运行

```bash
cjpm run
# 或
./target/release/bin/main
```

### 端口

| 端口 | 用途 |
|------|------|
| 6809 | 客户端连接 (Pilot / ATC) |
| 3011 | 服务器间互联 |
| 3010 | Telnet 管理终端 |
| 8080 | HTTP REST API |

### 管理命令

```bash
telnet localhost 3010
> servers       # 查看在线服务器
> clients       # 查看在线客户端
> kill <cid>    # 踢出用户
> cert          # 证书管理
> metar ZGGG    # 查询 METAR 天气
> distance CSN1 CSN2  # 计算两机组距离
> range CSN1    # 查看通信范围
> dump          # 调试转储
> help          # 完整命令列表
```

### HTTP API

```bash
# 服务器状态
curl http://localhost:8080/api/status

# 提交飞行计划
curl -X POST "http://localhost:8080/api/flightplan?callsign=CSN1275&cid=1001&fp_data=FP_DATA"

# 查询飞行计划
curl "http://localhost:8080/api/flightplan?callsign=CSN1275"

# 删除飞行计划
curl -X DELETE "http://localhost:8080/api/flightplan?callsign=CSN1275"
```

---

## 配置文件

| 文件 | 用途 |
|------|------|
| `fsd.conf` | 主配置（端口、数据库、HTTP） |
| `cert.txt` | 用户证书，格式：`CID password level` |
| `motd.txt` | 客户端登录欢迎消息 |

---

## Linux 部署

### 环境变量

```bash
export CANGJIE_HOME=/opt/cangjie
export PATH=$CANGJIE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CANGJIE_HOME/runtime/lib/linux_x86_64_cjnative:$LD_LIBRARY_PATH
```

### 管理脚本

```bash
./deploy.sh   # 首次部署（解压+编译+启动）
./fsd_d.sh    # 重启
./killfsd.sh  # 停止
```

---

## 客户端配置

- **Squawkbox**: 连接 localhost:6809，填写 CID 和密码（与 cert.txt 对应）
- **EuroScope**: 同上，选择 FSD 协议
- **whazzup.txt**: 自动生成在运行目录，供 PHP 网站读取在线列表

---

## 技术栈

- **语言**: 仓颉 (Cangjie) 1.1.0+
- **包管理**: cjpm
- **协议**: FSD 4.0（兼容原版 FSFDT FSD Unix/Windows Server）

---

## 致谢

- Marty Bochane — 原版作者
- 华为仓颉团队

---

**FSD_Cangjie v4.1.0 — CAPTAIN 1275**
