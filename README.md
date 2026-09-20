# 🇨🇳 Google 定位重定向与维护工具 (GoogleToChina)

**专为代理服务开发的高效定位维护与网络测试工具，全面兼容全平台与 Alpine LXC / Docker 环境**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu%20%7C%20CentOS%20%7C%20Alpine-lightgrey.svg)]()
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)]()

</div>

---

> [!CAUTION]
> ### ⚠️ 警告与免责声明
> 1. **仅供技术测试与研究**：本脚本仅用于个人网络环境测试、学术研究及网络流量行为分析。**严禁用于任何非法用途或商业获利**。
> 2. **使用者自负风险**：使用者在下载、安装或运行本脚本时，即代表已明确理解相关技术原理。因不当使用所导致的服务异常、IP 封禁或任何法律责任，均由使用者自行承担，开发者概不负责。
> 3. **遵守当地法律**：请确保在符合您所在国家或地区法律法规的前提下使用本工具。

---

## 📖 项目简介

`sz.sh` 是一款专为代理服务环境设计的自动化运维测试工具。通过自动化配置 DNS 分流解析规则，并配合后台多维度 HTTP 请求保活机制（Location Keep-Alive），用于测试与维持 Google 相关服务在特定地理位置（`zh-CN`）的响应表现。

本工具经过极致轻量化设计，完美支持各类 Linux 发行版、KVM 虚拟机以及 **Alpine LXC / Docker 极简容器环境**。

---

## ✨ 核心特性

- 🚩 **状态实时感知**：菜单顶部动态检测并直观展示当前系统的重定向模式状态（`[已开启]` / `[已关闭]`）。
- ⚡ **多维保活机制**：后台服务模拟移动端 Chrome、Google Services ，采用动态随机间隔发包，确保测试连通性。
- 🐧 **全平台与容器兼容**：
  - 无缝兼容 OpenRC (Alpine) 与 Systemd 级初始化系统。
  - 自动识别 Alpine 环境并智能配置 `community` / `testing` 软件源。
  - 低内存（LXC/KVM）环境下自动构建 Swap 机制，防止 OOM 崩溃。
- 🧼 **界面极简专业**：隐藏内部敏感组件名称，保持命令行交互界面整洁一致。
- 🚀 **快捷指令集成**：首次运行后自动注册系统全局指令，只需输入 `sz` 即可随时呼出管理控制台。


---

## 🛠️ 快速开始

在支持的 Server 终端中执行以下单行命令即可完成部署与运行：
```bash
bash <(curl -sSL https://raw.githubusercontent.com/edmond1294/GoogleToChina/main/sz.sh)
```

💡 提示：完成初始安装后，后续只需在命令行中输入 sz 即可直接进入管理控制台。
