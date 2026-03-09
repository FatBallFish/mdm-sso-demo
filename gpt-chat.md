要实现类似 **Jamf Connect** 的功能，本质上是 **替换 / 扩展 macOS 登录窗口（LoginWindow）的认证流程**，让系统在用户登录时通过 **SSO / IdP（Identity Provider）** 验证身份，并在本地创建或同步用户。

在 macOS 体系里，这类能力主要通过 **Authentication Plug-in + LoginWindow UI 扩展 + IdP 集成**实现。下面我从 **系统机制、需要准备的组件、开发步骤、关键技术点**几个方面完整讲一下。

---

# 一、先理解 macOS 登录体系

macOS 登录流程主要由 **OpenDirectory + Authorization Services + LoginWindow** 组成。

核心流程：

1. 用户进入 **LoginWindow**
2. 输入用户名密码
3. macOS 调用 **Authentication Mechanism**
4. 通过 **Authorization Plug-in** 执行认证
5. 成功后：

   * 创建/解锁用户
   * 加载用户 session

Apple 允许开发者通过 **Authorization Plug-in** 插入自己的认证逻辑。

Jamf Connect 就是：

```
LoginWindow
     ↓
Jamf Authorization Plugin
     ↓
SSO (Okta / Azure AD / Google)
     ↓
验证成功
     ↓
创建本地账户 + 同步密码
```

---

# 二、实现类似 Jamf Connect 的能力需要的组件

要实现这个系统，一般需要 **4个模块**：

### 1 Identity Provider (SSO)

支持的协议通常是：

* **OpenID Connect**
* **OAuth 2.0**
* **SAML 2.0**

常见 IdP：

* Okta
* Microsoft Entra ID
* Google Workspace

通常建议用 **OIDC**。

---

### 2 macOS Authorization Plugin

核心组件。

Apple API：

* **Authorization Services**

插件类型：

```
Authorization Plugin
    Mechanisms
        login
        authenticate
```

这个插件可以：

* 替换 loginwindow UI
* 调用 SSO
* 返回认证结果

Jamf Connect 的核心就是这个。

插件路径：

```
/Library/Security/SecurityAgentPlugins/
```

---

### 3 Login UI

需要一个 **自定义登录 UI**。

技术实现：

* Cocoa / Swift
* WebView (加载 IdP 登录页)

Jamf Connect 就是：

```
LoginWindow
   ↓
Jamf UI
   ↓
WebView
   ↓
IdP 登录
```

UI要做的事情：

* 加载 OIDC authorize endpoint
* 用户登录
* 获取 token
* 验证 token

---

### 4 本地账户同步模块

SSO 登录成功后需要：

1. 创建本地用户
2. 同步密码
3. 绑定 Keychain
4. 解锁 FileVault

需要调用：

```
OpenDirectory
dscl
sysadminctl
```

或者 API：

* **OpenDirectory**

常见流程：

```
SSO login success
     ↓
检查本地用户
     ↓
不存在 → 创建
     ↓
设置密码
     ↓
登录
```

---

# 三、开发前需要准备的东西

## 1 Apple Developer 账号

必须。

需要：

```
Developer ID
macOS signing certificate
```

因为：

```
Login plugin 必须签名
```

---

## 2 IdP 应用注册

例如：

Azure / Okta

需要配置：

```
client_id
redirect_uri
scope
issuer
```

OIDC endpoints：

```
/authorize
/token
/jwks
/userinfo
```

---

## 3 macOS 系统权限

插件必须安装在：

```
/Library/Security/SecurityAgentPlugins
```

并注册：

```
/etc/authorization
```

---

# 四、核心开发流程

## Step 1 实现 Authorization Plugin

创建 bundle：

```
MyLoginPlugin.bundle
```

实现接口：

```
AuthorizationPluginCreate
AuthorizationMechanismCreate
AuthorizationMechanismInvoke
```

典型结构：

```
Plugin
  Mechanism: login
  Mechanism: authenticate
```

伪代码：

```
InvokeMechanism() {

    showLoginUI()

    token = OIDCLogin()

    if verify(token) {

        createLocalUser()

        setPassword()

        return success

    } else {

        return fail

    }
}
```

---

## Step 2 登录 UI

用 Swift 写一个窗口：

```
NSWindow
   WKWebView
```

加载：

```
https://idp.com/oauth2/authorize
```

监听：

```
redirect_uri
```

获取：

```
id_token
access_token
```

---

## Step 3 Token 验证

验证：

```
JWT signature
issuer
audience
expiration
```

可以用库：

* SwiftJWT

---

## Step 4 创建本地用户

如果用户不存在：

```
sysadminctl -addUser
```

或 API：

```
ODNode
ODRecord
```

创建用户：

```
uid
gid
home
shell
```

---

## Step 5 同步密码

为了让本地用户能解锁：

```
dscl . -passwd
```

Jamf Connect 的逻辑：

```
SSO password → local password
```

---

## Step 6 FileVault 解锁

如果设备启用：

* **FileVault**

需要同步：

```
SecureToken
```

命令：

```
sysadminctl -secureTokenOn
```

否则：

```
用户无法解锁磁盘
```

---

# 五、MDM 配置

企业环境通常通过 **MDM 下发配置**。

常见配置：

```
OIDC endpoints
client id
domain allowlist
user mapping
```

例如：

* Jamf Pro
* Microsoft Intune

通过：

```
Configuration Profile
```

---

# 六、开发难点

### 1 FileVault

最大难点。

因为：

```
登录前磁盘未解锁
```

所以：

```
SSO 登录 + 本地用户 + SecureToken
```

需要 carefully design。

---

### 2 LoginWindow 限制

登录窗口环境：

```
无用户 session
权限受限
UI 能力有限
```

很多 API 不能用。

---

### 3 网络依赖

SSO 需要网络。

需要设计：

```
offline login
cached credential
```

Jamf Connect 就有：

```
offline login mode
```

---

### 4 Apple 不鼓励第三方登录替换

Apple 官方更推荐：

* **Platform SSO**

这是 Apple 近几年推出的新方案。

---

# 七、更推荐的新架构（Apple官方）

Apple 现在推荐：

### Platform SSO

系统级 SSO 插件。

优点：

```
无需替换 loginwindow
系统原生支持
更安全
```

支持：

```
Azure AD
Okta
Kerberos
```

Jamf 新版本其实也开始支持这个。

---

# 八、如果你要自己做一个“Jamf Connect”

推荐技术架构：

```
Login Plugin
      ↓
Swift UI
      ↓
WKWebView
      ↓
OIDC login
      ↓
JWT verify
      ↓
Local account create
      ↓
SecureToken enable
```

组件：

```
Authorization Plugin
OIDC client
User Provisioning
Password Sync
MDM config
```

---

# 九、开源参考

可以参考这些实现：

* NoMAD Login
* Jamf Connect

NoMAD Login 是早期 Jamf Connect 的原型。

---

# 十、开发工作量评估

如果从零做一个类似 Jamf Connect：

工程规模大约：

```
20k - 40k lines
```

需要：

```
macOS security
SSO
OpenDirectory
FileVault
MDM
```

开发周期：

```
2-4 人月（基础版本）
6-12 人月（企业级）
```

---

如果你愿意，我可以再深入讲三个非常关键但很少有人真正讲清楚的部分：

1️⃣ **Jamf Connect 如何在 FileVault 锁屏前完成 SSO 登录**
2️⃣ **LoginWindow Authorization Plugin 的完整实现结构**
3️⃣ **如何实现 Offline Login（企业环境必备）**

这三个基本是 **实现 Jamf Connect 的核心技术难点**。

下面把你关心的三个关键点拆开讲：

1️⃣ **FileVault 解锁前如何实现 SSO 登录**
2️⃣ **LoginWindow Authorization Plugin 的完整结构**
3️⃣ **Offline Login 的实现策略**

这些正是 **Jamf Connect** 和 **NoMAD Login** 这类产品的核心工程难点。

---

# 一、FileVault 锁屏前如何实现 SSO 登录

首先要理解 **FileVault** 的登录流程。

## 1 FileVault 登录阶段其实有两个

macOS 启动过程：

```
Boot ROM
  ↓
FileVault unlock screen
  ↓
disk unlocked
  ↓
macOS loginwindow
  ↓
user session
```

关键点：

**SSO 插件只能在 loginwindow 阶段运行。**

也就是说：

```
FileVault 解锁阶段
    ❌ 无法运行第三方插件
```

---

## 2 Jamf Connect 的解决方案

Jamf Connect 的设计逻辑：

```
第一次登录
    ↓
SSO 登录
    ↓
创建本地用户
    ↓
授予 SecureToken
    ↓
允许 FileVault 解锁
```

之后的流程：

```
启动
 ↓
FileVault unlock
 ↓
本地用户密码
 ↓
进入 macOS
 ↓
Jamf Connect 再做 SSO
```

所以真实逻辑是：

```
FileVault 使用本地密码
SSO 负责同步密码
```

不是直接 SSO 解锁磁盘。

---

## 3 SecureToken 是关键

macOS 需要用户拥有 **SecureToken** 才能解锁 FileVault。

启用：

```
sysadminctl -secureTokenOn user
```

SecureToken 关系：

```
admin user
   ↓
enable token
   ↓
new user
```

典型流程：

```
管理员账户
   ↓
创建 SSO 用户
   ↓
赋予 SecureToken
   ↓
用户可解锁 FileVault
```

---

## 4 SSO 密码同步

Jamf Connect 的核心机制：

```
SSO password = local password
```

登录流程：

```
SSO login
   ↓
verify token
   ↓
dscl change password
```

这样：

```
FileVault password
=
SSO password
```

用户体验就变成：

```
开机 → 输入 SSO 密码
```

---

# 二、Authorization Plugin 的完整结构

macOS 登录认证框架：

**Authorization Services**

核心对象：

```
Authorization Plugin
    Mechanism
```

---

## 1 Plugin bundle 结构

```
MyLoginPlugin.bundle
 ├── Contents
 │   ├── Info.plist
 │   ├── MacOS
 │   │   └── plugin binary
 │   └── Resources
```

安装位置：

```
/Library/Security/SecurityAgentPlugins/
```

---

## 2 Plugin 生命周期

插件需要实现几个 C 接口：

```c
AuthorizationPluginCreate()
AuthorizationPluginDestroy()

AuthorizationMechanismCreate()
AuthorizationMechanismInvoke()
AuthorizationMechanismDeactivate()
AuthorizationMechanismDestroy()
```

流程：

```
loginwindow
    ↓
AuthorizationPluginCreate
    ↓
MechanismCreate
    ↓
MechanismInvoke
```

---

## 3 登录机制链

macOS 登录是 **mechanism chain**。

默认：

```
loginwindow:login
loginwindow:authenticate
loginwindow:success
```

你可以替换：

```
loginwindow:login
myplugin:oidc-login
loginwindow:success
```

配置在：

```
/etc/authorization
```

例如：

```plist
<key>system.login.console</key>
<array>
   builtin:policy-banner
   myplugin:oidc-login
   builtin:login-success
</array>
```

---

## 4 MechanismInvoke 的逻辑

核心函数：

```c
OSStatus MechanismInvoke(
    AuthorizationMechanismRef mechanism
)
```

典型逻辑：

```
show login UI
      ↓
OIDC login
      ↓
verify token
      ↓
create user
      ↓
return allow
```

伪代码：

```c
if (loginSuccess) {

    AuthorizationCallbacks->SetResult(
        mechanism,
        kAuthorizationResultAllow
    )

} else {

    AuthorizationCallbacks->SetResult(
        mechanism,
        kAuthorizationResultDeny
    )

}
```

---

## 5 UI 的实现方式

因为运行在 loginwindow 环境：

推荐：

```
Swift + Cocoa
WKWebView
```

流程：

```
Authorization plugin
      ↓
launch login app
      ↓
SSO web login
```

Jamf Connect 其实就是这样。

---

# 三、Offline Login 的实现

企业环境 **必须支持离线登录**。

否则：

```
无网络 = 无法登录电脑
```

---

## 1 Offline Login 基本思路

缓存凭据。

```
第一次 SSO
      ↓
保存 credential
      ↓
离线验证
```

Jamf Connect 保存：

```
username
password hash
token info
```

---

## 2 缓存数据

典型数据：

```
user
password hash
salt
token expiry
```

不要保存明文密码。

可以保存：

```
PBKDF2 hash
```

或者：

```
bcrypt
```

---

## 3 登录逻辑

登录逻辑变成：

```
if network available
    → SSO login
else
    → offline verify
```

验证方式：

```
hash(input_password) == stored_hash
```

---

## 4 缓存存储

安全存储方式：

macOS 推荐：

**Keychain Services**

或者：

```
/var/db/
```

但必须：

```
root only
```

权限：

```
600
```

---

## 5 Token refresh

如果 token 过期：

```
online → refresh token
offline → allow cached login
```

Jamf Connect 有策略：

```
offline login days = 7
```

超过就必须联网。

---

# 四、真实企业级流程

完整登录流程：

```
Mac boot
   ↓
FileVault unlock (local password)
   ↓
macOS loginwindow
   ↓
Authorization plugin
   ↓
SSO login
   ↓
verify OIDC token
   ↓
create / sync user
   ↓
set local password
   ↓
enable SecureToken
   ↓
login
```

离线：

```
Mac boot
   ↓
FileVault unlock
   ↓
loginwindow
   ↓
offline credential check
   ↓
login
```

---

# 五、真正最难的两个工程问题

### 1 密码同步

当用户修改 IdP 密码：

```
SSO password changed
```

需要：

```
update local password
```

否则：

```
FileVault password mismatch
```

Jamf Connect 通过：

```
login-time password sync
```

解决。

---

### 2 用户映射

SSO 用户：

```
user@company.com
```

本地用户：

```
user
```

需要 mapping：

```
OIDC claim → local username
```

例如：

```
preferred_username
email
sub
```

---

# 六、Apple 新方案（建议关注）

Apple 正在推：

**Platform SSO**

优点：

```
系统级 SSO
无需 hack loginwindow
更安全
```

未来企业环境基本都会转这个。

---

💡 如果你真的打算开发一个 **Jamf Connect 类产品**，我可以再给你讲三个更深层的东西（这些是很多实现踩坑的地方）：

1️⃣ **Jamf Connect 为什么要用 helper app 而不是直接在 plugin 里做 UI**
2️⃣ **如何在 loginwindow 环境安全地打开 WKWebView**
3️⃣ **如何处理 FileVault 用户列表同步（否则用户不会出现在解锁界面）**

这三个基本是 **实现可商用产品的关键细节**。
