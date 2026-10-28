# Debian kernel audit

一个只读、离线的 Bash 自查脚本，规则核实日期为 **2026-10-28**。

覆盖 6 个 CVE（5 组）：Copy Fail、Dirty Frag 两项、Fragnesia、TCP IPv4 UAF（研究展示 MPTCP 远程攻击）、PwnEscape。

## 执行

下载完整文件后运行：

```bash
bash scripts/debian-kernel-audit.sh
```

文件也支持 `curl -fsSL <真实的 raw 文件 URL> | bash`。使用此形式时，在调用方启用 `pipefail`，以便下载失败时返回非零状态。优先使用固定提交 SHA 的 HTTPS 地址。脚本将入口函数放在最后一行，不在定义函数时执行检查。

无需 root；root 可以看到更多监听进程信息。在服务器宿主系统运行，而不是只在 Docker 容器中运行。报告可能包含本机地址、端口和进程名，分享前按需打码。

脚本不执行漏洞利用、不联网、不写报告文件、不安装软件、不修改 sysctl/防火墙、不加载内核模块、不重启服务。

## 判断依据

脚本核对 `uname -r`、`uname -v`、与运行内核名称对应的已安装镜像包版本及源包。不会因为磁盘上安装了更新的镜像，就将旧的运行内核判为已修复。内核包版本与运行构建不一致时返回 UNKNOWN。

| CVE | Debian 12 / 官方 6.1 | Debian 13 / 官方 6.12 |
| --- | --- | --- |
| CVE-2026-31431 | 6.1.170-1 | 6.12.85-1 |
| CVE-2026-43284 | 6.1.170-3 | 6.12.86-1 |
| CVE-2026-43500 | 6.1.170-3 | 6.12.86-1 |
| CVE-2026-46300 | 6.1.174-1 | 6.12.90-1 |
| CVE-2026-98432 | 6.1.190-1 | 6.12.113-1 |
| CVE-2026-99999 | 6.1.190-1 | 6.12.113-1 |

Debian 12 的官方 `linux-6.12` 源包分支，仅采用已核实覆盖全部六项的 `6.12.113-1~deb12u1` 基线；更低版本不据此证明可利用。自定义、其他 backports、厂商、NixOS 内核以及未核实的系列组合均返回 UNKNOWN，避免将 Debian 包版本规则错误套用到其他内核。

- `FIXED`：运行构建与已安装包一致，并达到对应官方修复基线。
- `BELOW_BASELINE`：低于已核实基线，需要更新或独立核实回移补丁/热补丁，不表示已证明可以利用。
- `UNKNOWN`：证据不足。容器内无法核实宿主内核对应的安装包。

退出码只描述内核修复基线：0 为全部六项达到基线；1 为至少一项未达基线；2 为无法精确判定；64 为参数错误。监听检查失败会单独显示 UNKNOWN，不能将退出码 0 当成服务器整体安全认证。

## 攻击面检查的范围

附带只读检查 MPTCP 开关与监听、TCP 请求迁移参数、TCP 监听端口、相关可见模块、虚拟化和 livepatch 线索。缺少工具、权限不足和查询报错会输出限制。

没有 MPTCP 监听不代表通用 TCP 内核漏洞已修复；模块未加载不代表无法自动加载；`tcp_migrate_req=0` 不构成完整修复。网络检查仅限当前命名空间，不能确认云安全组、公网可达性、其他容器或云平台宿主机状态。虚拟机内更新不能代替云厂商更新宿主机。

这是静态规则快照，不是全部漏洞扫描器，也不检查 Xray/Nginx 等应用漏洞或入侵历史。低版本如果已应用热补丁，需要核实热补丁供应方覆盖的 CVE。检查依赖本机可信的内核构建信息和软件包数据库，不验证数字签名或防篡改状态。

## 来源与验证

每项基线来自 Debian Security Tracker：

- https://security-tracker.debian.org/tracker/CVE-2026-31431
- https://security-tracker.debian.org/tracker/CVE-2026-43284
- https://security-tracker.debian.org/tracker/CVE-2026-43500
- https://security-tracker.debian.org/tracker/CVE-2026-46300
- https://security-tracker.debian.org/tracker/CVE-2026-98432
- https://security-tracker.debian.org/tracker/CVE-2026-99999

本地验证：

```bash
bash -n scripts/debian-kernel-audit.sh
python3 scripts/tests/test-debian-kernel-audit.py
```

模拟用例覆盖版本边界、Debian 修订号、运行旧内核但已安装新镜像、构建版本不一致、容器、自定义内核、未知分支、Debian 13、Debian 12 的 6.12 分支，以及监听查询失败和标准输入执行。测试在临时目录中运行，不修改真实服务器配置。
