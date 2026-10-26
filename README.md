# 🚀 Nezha Tools - 哪吒探针主控地址一键切换工具

![License](https://img.shields.io/badge/License-MIT-green.svg)
![Shell](https://img.shields.io/badge/Shell-Bash-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)

专为**哪吒监控（Nezha Monitoring）面板迁移**打造的受控端（Agent）维护脚本。无需手动逐台寻找配置文件、修改 IP 和重启服务，支持**自动探测正在运行的真实配置文件**、**智能保留原端口**、**自动备份**及**服务自启验证**。

---

## ⚡ 一键执行命令（Quick Start）

请以 `root` 权限在需要切换主控地址的受控端（Agent）服务器上执行以下命令：

### 1. 标准交互式命令（海外服务器通用）
执行后将进入彩色可视化菜单，自动高亮当前正在运行的配置文件：
```bash
curl -sL https://raw.githubusercontent.com/Wucat109/nezha-tools/refs/heads/main/nezha-ip.sh | bash
```

### 2. 国内服务器加速命令（中国大陆节点推荐）
针对国内服务器连接 GitHub Raw 缓慢或超时的情况，已集成 `ghfast.top` 加速前缀：
```bash
curl -sL https://ghfast.top/https://raw.githubusercontent.com/Wucat109/nezha-tools/refs/heads/main/nezha-ip.sh | bash
```

### 3. 极速免交互命令（适合多台小鸡批量群发执行）
通过 `-s` 参数直接传入新的主控 IP（或 `IP:端口`），脚本将**自动选中当前正在运行的配置文件、自动保留原端口、自动修改并重启服务，全程 0 交互 1 秒完成**：
```bash
# 仅修改 IP/域名（自动保留原配置文件中的端口号）：
curl -sL https://raw.githubusercontent.com/Wucat109/nezha-tools/refs/heads/main/nezha-ip.sh | bash -s 新主控IP或域名

# 同时修改 IP/域名 和 端口号：
curl -sL https://raw.githubusercontent.com/Wucat109/nezha-tools/refs/heads/main/nezha-ip.sh | bash -s 新主控IP或域名:端口号
```
*(💡 国内机器批量执行只需将上方的 `https://raw...` 替换为 `https://ghfast.top/https://raw...` 即可)*

---

## ✨ 核心特性

* 🔍 **精准识别生效配置**：通过扫描系统进程（`ps`）与系统服务（`systemd`），对 `/opt/nezha/agent` 下的多个配置文件（如历史残留的别名配置 `config-*.yml`）进行状态标记：
  * `[★ 进程运行中]`：当前 `nezha-agent` 进程实际挂载的配置文件（默认优先选中）。
  * `[服务已绑定]`：`nezha-agent.service` 中绑定但当前未运行的配置文件。
  * `[未激活/残留]`：目录中存在但未被调用的冗余配置文件。
* 🧠 **智能端口保留机制**：
  * 输入 `1.2.3.4`（不带端口）👉 自动提取并保留原配置中的端口（例如自动拼接为 `1.2.3.4:8008`）。
  * 输入 `1.2.3.4:5555`（自带端口）👉 直接覆盖为新的 IP 与新端口。
* 🛡️ **安全自动备份**：修改任意配置文件前，自动在同级目录生成 `.bak` 备份文件（如 `config.yml.bak`），防止误操作。
* 🔄 **服务自动重启与自检**：修改完成后自动遍历并重启系统中的 `nezha-agent` 服务，并实时检测输出 `Active (Running)` 状态。

---

## 🖥️ 交互界面预览

```text
============================================================
          哪吒探针 (Nezha Agent) 主控地址一键切换工具        
============================================================

🔍 扫描到以下哪吒探针配置文件：

  [1] /opt/nezha/agent/config.yml            [★ 进程运行中]
      └─ 当前主控 (server): 192.168.1.100:8008

  [2] /opt/nezha/agent/config-backup.yml     [未激活/残留]
      └─ 当前主控 (server): 10.0.0.1:5555

  [0] 修改以上全部配置文件
------------------------------------------------------------
👉 请选择要修改的配置文件编号 [默认: 1，输入 q 退出]: 1

提示：如果只输入 IP 或域名（如 1.2.3.4），脚本会自动保留原来的端口号；
      如果输入 IP:端口（如 1.2.3.4:8008），则会连同端口一起修改。
✏️  请输入新的主控 Server 地址: 8.8.8.8

------------------------------------------------------------
✅ 已更新: /opt/nezha/agent/config.yml
   ├─ 原地址: 192.168.1.100:8008
   ├─ 新地址: 8.8.8.8:8008
   └─ 备份至: /opt/nezha/agent/config.yml.bak
------------------------------------------------------------
🔄 正在重启哪吒探针服务使配置生效...
🎉 服务 nezha-agent.service 重启成功，当前状态: Active (Running)
============================================================
```

---

## 🛠️ 进阶用法：安装为本地全局快捷命令

如果你需要在某台机器上频繁调试切换，可以将脚本固化到系统环境变量中：

```bash
curl -sL https://raw.githubusercontent.com/Wucat109/nezha-tools/refs/heads/main/nezha-ip.sh -o /usr/local/bin/nezha-ip && chmod +x /usr/local/bin/nezha-ip
```

安装完成后，在终端任意位置直接输入以下命令即可呼出面板：
```bash
nezha-ip
```

---

## 🔙 配置回滚（恢复原配置）

如果填错了主控 IP 想要恢复修改前的状态，脚本在每次修改时都自动生成了 `.bak` 备份文件，执行以下命令即可一键还原并重启：

```bash
cp /opt/nezha/agent/config.yml.bak /opt/nezha/agent/config.yml && systemctl restart nezha-agent
```
