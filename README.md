# FSD_Cangjie

![License](https://img.shields.io/badge/license-Apache--2.0-blue)
![Language](https://img.shields.io/badge/language-Cangjie-orange)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20HarmonyOS-informational)
![G-Star](https://img.shields.io/badge/AtomGit-G--Star%20孵化项目-0969da)

> 🏅 本项目已入选 **AtomGit G-Star 孵化计划**。

📖 **在线文档**：[docs.ldpfly.cn](https://docs.ldpfly.cn) （使用指南 · 配置 · 部署 · FSD 通讯协议参考 · HTTP API）

基于 **华为仓颉（Cangjie）** 语言的飞行模拟联机服务器（Flight Simulator Daemon）。
移植自 Marty Bochane 的 **原版 FSD**（公共领域），用仓颉重构并扩展，可运行于 **Linux** 与 **HarmonyOS / OpenHarmony（aarch64）**。

> 原版 FSD 为公共领域（public domain）。本项目的**仓颉实现、并发模型与扩展功能**归本仓库作者所有。

## 特性

- **协议兼容**：兼容 FSD / SquawkBox / FSInn 客户端协议（`#AP/#AA/#DP/@/%/#TM/$FP/$!!` 等完整指令集），支持 MOTD、位置广播、飞行计划、天气。
- **完整接口**：客户端 `6809`、服务器互联 `3011`、系统管理 `3010`、HTTP API `8080`、语音 `6808`。
- **高性能发送**：每连接独立输出邮箱（`OutBuf`，字节累积缓冲 + 唤醒令牌）+ 合并窗口批量写出，慢客户端不阻塞广播，多核可扩展。
- **稳定**：`serve` 退出时按连接 ID 统一回收，杜绝连接表泄漏；数据库不可用时自动回退 `cert.txt`。
- **跨平台**：Linux（x86_64）与 HarmonyOS / OpenHarmony（aarch64）单二进制运行。

## 端口一览

| 端口 | 用途 | 对外 |
| --- | --- | --- |
| `6809` | 客户端接口（机组 / 管制） | 是 |
| `3011` | 服务器互联接口 | 按需 |
| `3010` | 系统管理口（运维命令） | 否 |
| `8080` | HTTP API | 按需 |
| `6808` | 语音服务 | 按需 |

## 目录结构

```
src/            仓颉源码
vendor/         MySQL 驱动（第三方）
unix/           Linux 部署：fsd_d.sh / killfsd.sh / deploy.sh / 示例配置
harmonyos/      HarmonyOS 构建脚本 + 3010 控制台客户端(admin)
cjpm.toml       构建配置
```

## 构建（Linux）

依赖：仓颉 SDK 1.2.0 + stdx。

```bash
source /opt/cangjie/envsetup.sh
export CANGJIE_STDX_PATH=/opt/cangjie/linux_x86_64_cjnative/static/stdx
cjpm build
# 产物: target/release/bin/main
```

## 构建（HarmonyOS / OpenHarmony aarch64）

需要：**鸿蒙仓颉 SDK**（`cangjie-sdk-linux-x64-ohos-1.2.0`）+ **ohos-aarch64 stdx** + **OHOS sysroot**（DevEco Studio 自带 `sdk/default/openharmony/native/sysroot`）。
详见 `harmonyos/scripts/`（`_build_ohos.sh` 等）。

产物需用 **`binary-sign-tool sign -selfSign 1`** 对可执行文件及所依赖的全部 `.so` 自签名，才能在鸿蒙 HiShell 中运行。

## 部署 / 运行

```bash
# Linux
cd unix && cp fsd.conf.example fsd.conf   # 编辑配置
cp cert.txt.example cert.txt              # 编辑证书
./fsd_d.sh                                 # 启动/重启（优雅通知客户端后重启）
./killfsd.sh                               # 停止

# HarmonyOS：在家目录解压发布包后
./fsd_d.sh
```

## 系统管理接口（端口 3010）

```bash
telnet 127.0.0.1 3010        # 注意：host 与 port 用空格分隔
pwd <管理密码>               # 认证
help / clients / info / time
shutdown                     # 优雅关机
```

## 安全提示

- **3010 管理接口只应绑定本机或内网**，不要暴露公网（默认密码时极其危险）。
- **务必修改默认管理密码**，并保护好 `fsd.conf` / `cert.txt`（已在 `.gitignore` 中）。
- 云服务器仅放行必要端口。

## 参与贡献

欢迎提交 Issue / PR。详见 [CONTRIBUTING.md](CONTRIBUTING.md)，开发历史见 [CHANGELOG.md](CHANGELOG.md)。

## 许可与致谢

本项目源码以 **Apache-2.0** 许可发布（见 `LICENSE`）。
原版 FSD 由 **Marty Bochane** 开发，列为公共领域，谨致谢意。
