# LoginWindow SSO Demo 中文操作手册

## 1. 文档目的

本文档用于说明当前 `Option B / Jamf Connect 风格` demo 项目已经实现了哪些能力，以及如何在本机完成以下几类测试流程：

1. 安全推荐流程
   - 不修改当前系统 `LoginWindow`
   - 只验证本地 IDP、登录壳、绑定流程、离线流程、broker/daemon 链路
2. staging 安装流程
   - 把 demo 产物安装到一个临时目录
   - 验证 bundle、二进制、配置文件和 authdb 变换文件布局是否正确
3. 实验性系统接入流程
   - 把 plug-in 产物安装到系统目录
   - 生成并手动写入 `authorizationdb`
   - 验证 `system.login.console` 是否接入 demo 机制
4. 恢复与卸载流程

## 2. 当前项目已经实现的功能

### 2.1 本地 Demo IDP 服务

已实现一个本地 HTTP 服务，作为 demo 用的 SSO 身份校验服务。

支持接口：

- `GET /api/health`
- `POST /api/login`
- `POST /api/refresh`

代码位置：

- [DemoIDPServer](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoIDPServer/main.swift)

### 2.2 写死的测试账号

当前配置了 3 个固定测试账号：

- `demo.user / DemoPass123!`
- `it.admin / AdminPass123!`
- `qa.user / QAPass123!`

配置文件位置：

- [demo-idp.json](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/configs/demo-idp.json)

### 2.3 登录壳窗口

已经有一个原生 `AppKit + SwiftUI` 的登录壳程序，可用于演示：

- 输入用户名密码
- 在线登录
- 离线登录
- 未绑定时进入绑定页
- 绑定已有本地 short name
- 新建本地 short name

代码位置：

- [LoginViewModel.swift](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoLoginShellSupport/LoginViewModel.swift)
- [NativeLoginShellView.swift](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoLoginShellSupport/NativeLoginShellView.swift)
- [DemoLoginShell](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoLoginShell/main.swift)

### 2.4 账号绑定与离线登录策略

已经实现 demo 级别的账号同步服务，支持：

- 首次在线登录后缓存映射关系
- 绑定已有 short name
- 新建 short name
- 缓存密码指纹
- 离线登录宽限期判断

代码位置：

- [AccountSyncService.swift](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoAccountSyncSupport/AccountSyncService.swift)
- [LoginFlowCoordinator.swift](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoLoginShellSupport/LoginFlowCoordinator.swift)

### 2.5 daemon / broker / plug-in 进程链路

当前已经把原型拆成了几个可独立运行的进程：

- `DemoAccountSyncDaemon`
- `DemoLoginBroker`
- `DemoLoginShell`
- `DemoLoginPlugin.bundle`

其中：

- daemon 通过 `stdin/stdout JSON` 处理绑定、创建和离线校验请求
- broker 会输出未来 plug-in 可消费的 JSON 机制决策

代码位置：

- [DemoAccountSyncDaemon](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoAccountSyncDaemon/main.swift)
- [DaemonProtocol.swift](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoAccountSyncSupport/DaemonProtocol.swift)
- [AccountSyncCommandHandler.swift](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoAccountSyncSupport/AccountSyncCommandHandler.swift)
- [DemoLoginBroker](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoLoginBroker/main.swift)
- [MechanismDispositionPayload.swift](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/Sources/DemoLoginPluginSupport/MechanismDispositionPayload.swift)

### 2.6 plug-in bundle 打包

当前已经可以生成一个真实的 `.bundle` 产物：

- `dist/DemoLoginPlugin.bundle`

构建脚本：

- [build-login-plugin-bundle.sh](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/scripts/build-login-plugin-bundle.sh)

### 2.7 authorizationdb 规则变换与恢复

已经实现：

- 读取当前 `system.login.console`
- 在 `loginwindow:login` 后插入 `DemoLoginPlugin:login,privileged`
- 生成 backup plist
- 生成 demo plist
- 用 backup 恢复

脚本位置：

- [configure-loginwindow-authdb.sh](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/scripts/configure-loginwindow-authdb.sh)
- [restore-native-loginwindow.sh](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/scripts/restore-native-loginwindow.sh)

### 2.8 staging 安装与卸载

已实现：

- 把产物安装到指定 root
- 把 plug-in bundle、二进制、配置文件、authdb 变换文件一并写到 staging 目录
- 从 staging root 进行卸载

脚本位置：

- [install-jamf-style-demo.sh](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/scripts/install-jamf-style-demo.sh)
- [uninstall-jamf-style-demo.sh](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/scripts/uninstall-jamf-style-demo.sh)

## 3. 当前尚未实现的功能边界

下面这些能力目前还没有真正完成：

- 真实系统 `LoginWindow` 中弹出完整 SSO UI
- 真实本地用户创建
- 真实本地密码修改
- `SecureToken` 同步
- `FileVault` 相关流程
- 安装脚本自动 live 写入 `system.login.console`

换句话说：

- 当前已经能验证“架构链路、打包、安装、变换规则、进程交互”
- 但还不是一个真正能完全替代 `LoginWindow` 登录体验的成品

## 4. 建议的测试顺序

建议按下面顺序测试：

1. 本地 IDP 验证
2. 原生登录壳窗口验证
3. broker/daemon 链路验证
4. plug-in bundle 打包验证
5. staging 安装与卸载验证
6. authorizationdb 规则变换验证
7. 如果是专用测试机，再做实验性 live 接入

## 5. 准备工作

### 5.1 进入工作目录

```bash
cd /Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo
```

### 5.2 构建和跑测试

```bash
env HOME=$PWD/.home XDG_CACHE_HOME=$PWD/.swiftpm-cache CLANG_MODULE_CACHE_PATH=$PWD/.cache/clang swift test
env HOME=$PWD/.home XDG_CACHE_HOME=$PWD/.swiftpm-cache CLANG_MODULE_CACHE_PATH=$PWD/.cache/clang swift build
```

### 5.3 已通过的验证项

当前代码已经通过以下验证：

- `swift test`
- `swift build`
- `bash scripts/tests/idp_smoke_test.sh`
- `bash scripts/tests/login_broker_smoke.sh`
- `bash scripts/tests/plugin_bundle_smoke.sh`
- `bash scripts/tests/install_root_smoke.sh`
- `bash scripts/tests/uninstall_root_smoke.sh`
- `bash scripts/tests/authdb_transform_smoke.sh`
- `bash scripts/tests/authdb_restore_smoke.sh`

## 6. 安全推荐流程：不改系统 LoginWindow

这是最推荐的流程。

目标：

- 不修改当前机器系统登录链
- 只演示 demo 的业务流和链路能力

### 6.1 启动本地 IDP

```bash
./scripts/start-demo-idp.sh
```

另开一个终端，验证服务健康：

```bash
curl http://127.0.0.1:48080/api/health
```

期望返回：

```json
{"status":"ok"}
```

### 6.2 启动原生登录壳窗口

```bash
./scripts/start-login-shell.sh
```

如果你的仓库放在 `Documents`、`Desktop` 之类受 macOS 隐私权限保护的目录里，旧版本脚本可能会在 `swift run` 编译阶段报：

- `Operation not permitted`
- 无法写入 `.build/...`

当前脚本已经把 SwiftPM scratch/build 输出切到 `~/Library/Caches/DemoSSO/`，就是为了避开这个问题。

### 6.3 在窗口中演示登录与绑定流程

推荐操作：

1. 输入 `demo.user`
2. 输入 `DemoPass123!`
3. 保持 `Network available` 打开
4. 点击 `Sign In`

预期行为：

- 如果当前没有映射，会进入绑定页
- 绑定页中可填写本地 short name
- 点击 `Bind Existing Account` 或 `Create Local Account`
- 成功后会进入 success 状态

### 6.4 演示再次在线登录

使用相同账号再次登录：

- 如果已经存在映射，应直接进入 success

### 6.5 演示离线登录

完成一次在线登录后：

1. 关闭 `Network available`
2. 继续使用相同账号密码登录

预期行为：

- 进入 offline 成功状态

## 7. broker / daemon 链路验证

如果你不想手动点击 GUI，而是直接验证进程链路，可以执行：

```bash
bash scripts/tests/login_broker_smoke.sh
```

该脚本会自动验证：

1. 第一次未绑定时返回 `promptForAccountBinding`
2. 创建映射后返回 `allowLogin`

## 8. plug-in bundle 打包验证

### 8.1 手动构建 bundle

```bash
./scripts/build-login-plugin-bundle.sh
```

生成产物：

- `dist/DemoLoginPlugin.bundle`

### 8.2 自动 smoke test

```bash
bash scripts/tests/plugin_bundle_smoke.sh
```

验证项：

- bundle 目录存在
- `Contents/Info.plist` 存在
- 可执行二进制存在

## 9. staging 安装流程：不改系统，只写临时 root

适用于验证文件布局和安装脚本是否正确。

### 9.1 安装到临时目录

```bash
./scripts/install-jamf-style-demo.sh --root /tmp/demo-sso-lab --enable-authdb
```

安装完成后，临时目录中应包含：

- `/tmp/demo-sso-lab/Library/Security/SecurityAgentPlugins/DemoLoginPlugin.bundle`
- `/tmp/demo-sso-lab/Library/Application Support/DemoSSO/bin/DemoAccountSyncDaemon`
- `/tmp/demo-sso-lab/Library/Application Support/DemoSSO/bin/DemoLoginBroker`
- `/tmp/demo-sso-lab/Library/Application Support/DemoSSO/bin/DemoLoginShell`
- `/tmp/demo-sso-lab/Library/Application Support/DemoSSO/config/demo-idp.json`
- `/tmp/demo-sso-lab/Library/Application Support/DemoSSO/authdb/system.login.console.backup.plist`
- `/tmp/demo-sso-lab/Library/Application Support/DemoSSO/authdb/system.login.console.demo.plist`

### 9.2 staging 安装 smoke test

```bash
bash scripts/tests/install_root_smoke.sh
```

### 9.3 staging 卸载 smoke test

```bash
bash scripts/tests/uninstall_root_smoke.sh
```

### 9.4 手动卸载 staging 内容

```bash
./scripts/uninstall-jamf-style-demo.sh --root /tmp/demo-sso-lab
```

## 10. authorizationdb 规则生成与恢复

### 10.1 生成 authdb 变换结果

```bash
./scripts/configure-loginwindow-authdb.sh \
  --output-plist /tmp/system.login.console.demo.plist \
  --backup-file /tmp/system.login.console.backup.plist
```

该命令会：

1. 读取当前 `system.login.console`
2. 生成 backup plist
3. 生成 demo plist
4. 在 demo plist 中把 `DemoLoginPlugin:login,privileged` 插到 `loginwindow:login` 后面

### 10.2 验证 authdb 变换

```bash
bash scripts/tests/authdb_transform_smoke.sh
```

该测试会检查：

- `DemoLoginPlugin:login,privileged` 已被插入
- 插入位置在 `loginwindow:login` 之后、`builtin:login-begin` 之前
- 重复执行时不会插入两次

### 10.3 从 backup 恢复

```bash
./scripts/restore-native-loginwindow.sh \
  --backup-file /tmp/system.login.console.backup.plist \
  --output-plist /tmp/system.login.console.restored.plist
```

### 10.4 验证恢复逻辑

```bash
bash scripts/tests/authdb_restore_smoke.sh
```

## 11. 实验性系统接入流程

这一部分只建议在专用测试机上做。

### 11.1 风险提示

执行前请确保：

- 机器是测试机，不是日常工作主机
- 你有另一个本地管理员账号可用
- 最好先关闭 FileVault 测试
- 你明确知道如何进入恢复流程

### 11.2 安装到系统目录

```bash
sudo ./scripts/install-jamf-style-demo.sh --root / --enable-authdb
```

这一步会把产物安装到：

- `/Library/Security/SecurityAgentPlugins/DemoLoginPlugin.bundle`
- `/Library/Application Support/DemoSSO/bin/`
- `/Library/Application Support/DemoSSO/config/`
- `/Library/Application Support/DemoSSO/authdb/`

注意：

- 这一步不会自动修改 live `authorizationdb`
- 它只会生成 backup 和目标 plist

### 11.3 查看生成的 authdb 文件

```bash
plutil -p "/Library/Application Support/DemoSSO/authdb/system.login.console.demo.plist"
```

### 11.4 手动写入系统规则

```bash
sudo security authorizationdb write system.login.console < "/Library/Application Support/DemoSSO/authdb/system.login.console.demo.plist"
```

### 11.5 校验是否写入成功

```bash
security authorizationdb read system.login.console | grep "DemoLoginPlugin:login,privileged"
```

如果有输出，说明规则已写入。

### 11.6 进行实验

接下来你可以：

- 注销当前用户
- 或重启机器
- 观察 `LoginWindow` 链路是否加载到 demo 插件

但要注意：

- 当前 live 接入只验证 Authorization plug-in 是否被系统加载
- 当前系统登录界面仍然会先显示 macOS 原生账号密码输入框
- 当前 plug-in 会在原生登录链中执行一个安全的 pass-through，允许本地登录继续
- 这一步不是“完整 SSO 登录界面接管成品”

如果你期望的是：

- 注销后立即弹出自定义 SSO UI
- 完全替代原生账号密码输入框

那么当前仓库版本还没有实现到这一阶段。

### 11.7 观察插件日志

当前 plug-in 会通过 macOS Unified Logging 输出以下关键事件：

- `AuthorizationPluginCreate`
- `MechanismCreate`
- `MechanismInvoke allow`
- `MechanismDestroy`
- `PluginDestroy`

实时观察：

```bash
log stream --style compact --level info --predicate 'subsystem == "com.demo.sso.login-plugin"'
```

查看最近 10 分钟历史：

```bash
sudo log show --last 10m --style compact --predicate 'subsystem == "com.demo.sso.login-plugin"'
```

如果你想把系统相关进程一起带上排查，可以用：

```bash
sudo log show --last 10m --style compact --predicate '(subsystem == "com.demo.sso.login-plugin") OR (process == "authorizationhost") OR (process == "SecurityAgent") OR (process == "loginwindow")'
```

正常情况下，在一次成功的本地登录实验中，你至少应当能看到：

- `AuthorizationPluginCreate`
- `MechanismCreate`
- `MechanismInvoke allow`

如果规则已写入，但完全看不到这些日志，优先排查：

- `DemoLoginPlugin.bundle` 是否已安装到 `/Library/Security/SecurityAgentPlugins/`
- `system.login.console` 是否真的包含 `DemoLoginPlugin:login,privileged`
- 是否已经重新注销或重启，让 `loginwindow` 重新走认证链

## 12. 恢复原生 LoginWindow

### 12.1 从 backup 恢复 live authdb

```bash
sudo ./scripts/restore-native-loginwindow.sh \
  --backup-file "/Library/Application Support/DemoSSO/authdb/system.login.console.backup.plist" \
  --apply-live
```

### 12.2 检查恢复结果

```bash
security authorizationdb read system.login.console | grep "DemoLoginPlugin:login,privileged"
```

正常情况下不应再匹配到这一行。

### 12.2.1 如果已经写入 live authdb 且登录流程异常

优先目标是先恢复原生链路：

```bash
sudo ./scripts/restore-native-loginwindow.sh \
  --backup-file "/Library/Application Support/DemoSSO/authdb/system.login.console.backup.plist" \
  --apply-live
```

如果当前机器已经卡在登录窗口而无法进入桌面，请使用你现有的恢复手段之一执行上面的恢复命令：

- 另一位已登录的管理员用户会话
- `ssh` 到测试机
- macOS 恢复模式 / 单用户恢复手段

恢复后再重启或回到登录界面验证。

### 12.3 卸载系统文件

```bash
sudo ./scripts/uninstall-jamf-style-demo.sh --root /
```

如果你想保留状态目录用于调试：

```bash
sudo ./scripts/uninstall-jamf-style-demo.sh --root / --keep-state
```

## 13. 推荐演示顺序

如果你要给别人演示，我建议按下面顺序：

1. 启动本地 IDP
2. 启动登录壳窗口
3. 演示首次登录进入绑定页
4. 演示绑定已有账号或新建账号
5. 演示再次登录直接成功
6. 演示离线登录
7. 演示 broker 链路测试
8. 演示 plug-in bundle 打包
9. 演示 authdb 变换
10. 如果是测试机，再演示 live 写入与恢复

## 14. 一句话描述当前项目状态

当前项目已经可以完整验证以下内容：

- 本地 IDP
- 登录壳 UI
- 账号绑定 / 新建账号流程
- 离线登录判断
- daemon / broker / plug-in 的进程链路
- plug-in bundle 打包
- authorizationdb 规则生成与恢复
- staging 安装 / 卸载

但它还不是一个已经完成的系统级 LoginWindow 替代品，尚未真正实现：

- 完整系统登录拦截
- 真实本地账号创建
- 密码同步
- `SecureToken`
- `FileVault`

## 15. 相关文档

你还可以参考以下文档：

- [lab-setup.md](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/docs/runbooks/lab-setup.md)
- [manual-test-matrix.md](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/docs/runbooks/manual-test-matrix.md)
- [known-limitations.md](/Users/fatballfish/Documents/Projects/mdm-sso-demo/.worktrees/option-b-demo/docs/runbooks/known-limitations.md)
