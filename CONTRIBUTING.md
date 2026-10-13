# 贡献指南

感谢你对 FSD_Cangjie 的关注！欢迎通过 Issue 与 PR 参与共建。

## 开发环境

- **仓颉 SDK 1.2.0**（含 `cjpm`）与 **stdx**
- MySQL（可选，用于账号 / 飞行计划 / 轨迹）
- 可选：OpenHarmony 版仓颉 SDK（交叉编译到 HarmonyOS）

```bash
source /opt/cangjie/envsetup.sh
export CANGJIE_STDX_PATH=/opt/cangjie/linux_x86_64_cjnative/static/stdx
cjpm build          # 产物 target/release/bin/main
```

## 提交前自检

- 能通过 `cjpm build`（无新增错误）。
- 涉及网络的改动，请在本地起服务后自测：客户端登录、位置广播、系统管理口（3010）、HTTP API。
- **不要提交任何密钥**：`fsd.conf`、`cert.txt`、`bindings.json`、`config.json`（KOOK）等已在 `.gitignore`，切勿强行 `git add -f`。

## 代码约定

- 保持与现有代码风格一致；日志中**不要输出明文密码 / Token**。
- 涉及协议解析的改动，注意**边界检查**（数组下标、字段数、长度上限）。
- 共享状态（注册表、广播列表）务必考虑**并发安全**。

## PR 流程

1. Fork 本仓库并切出新分支：`feat/xxx` 或 `fix/xxx`。
2. 提交信息**清晰描述改动**（中文/英文均可）。
3. 发起 PR，说明：**动机、改动点、验证方式**。
4. 保持变更聚焦，一个 PR 解决一个问题。

## Issue 规范

- 描述**现象 / 复现步骤 / 预期**，尽量附日志（请**脱敏**）。
- 平台信息：Linux 发行版 / 架构，或 HarmonyOS 设备型号与版本。

## 许可与署名

- 本仓库源码以 **Apache-2.0** 发布（见 `LICENSE`）。
- 提交即表示你同意以该许可授权你的贡献。
- 本项目派生自 **Marty Bochane 的原版 FSD（公共领域）**，请**保留相关来源与署名**。

## 联系方式

- 仓库：[gitcode.com/CAPTAIN1275/FSD_Cangjie](https://gitcode.com/CAPTAIN1275/FSD_Cangjie)
- 问题反馈：在仓库提 Issue。
