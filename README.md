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
> servers    # 查看在线服务器
> clients    # 查看在线客户端
> kill <cid> # 踢出用户
> cert       # 刷新证书
> help       # 完整命令列表
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

**FSD_Cangjie v4.0.0 — CAPTAIN 1275**
