#!/usr/bin/env bash
# Debian kernel audit, snapshot 2026-10-28, v1.0.0
# Read-only, offline, no exploits, no package installation or configuration changes.
# Sources: https://security-tracker.debian.org/tracker/CVE-2026-{31431,43284,43500,46300,98432,99999}
# Exit codes: 0 = all six CVEs meet verified baseline; 1 = baseline not met;
#             2 = cannot classify; 64 = invalid arguments.
# The entire file must be received before the last line invokes main().

audit_main() {
    if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
        printf '%s\n' '需要 Bash 4 或更新版本。' >&2
        return 2
    fi
    local opt
    for opt in "$@"; do
        case "$opt" in
            --help|-h)
                printf '%s\n' \
                    '用法：bash debian-kernel-audit.sh [--help|--version]' \
                    '只读、离线检查，覆盖 6 个 CVE（5 组）。无需 root；root 可看到更多进程信息。' \
                    '精确基线：Debian 12 官方 6.1、Debian 13 官方 6.12。' \
                    'Debian 12 官方 linux-6.12 分支仅采用已核实的 6.12.113-1~deb12u1 总基线。' \
                    '其他发行版/自编译内核/容器/运行与包版本不一致：UNKNOWN。' \
                    '不检查入侵历史、全部 CVE、云安全组、其他网络命名空间或云厂商宿主机。' \
                    '退出码：0 全部达到基线；1 至少一项未达基线；2 无法判定；64 参数错误。'
                return 0 ;;
            --version)
                printf '%s\n' 'debian-kernel-audit 1.0.0 (baseline snapshot: 2026-10-28)'
                return 0 ;;
            *) printf '未知参数：%s\n' "$opt" >&2; return 64 ;;
        esac
    done

    local LC_ALL=C
    export LC_ALL
    local release build os_id os_version os_name
    release=$(uname -r) || return 2
    build=$(uname -v) || return 2
    os_id='' os_version='' os_name='unknown'
    if [[ -r /etc/os-release ]]; then
        # Parse data only: do not source/eval a file as shell code.
        os_id=$(awk -F= '$1=="ID" {v=substr($0,index($0,"=")+1); gsub(/^"|"$/,"",v); print v; exit}' /etc/os-release)
        os_version=$(awk -F= '$1=="VERSION_ID" {v=substr($0,index($0,"=")+1); gsub(/^"|"$/,"",v); print v; exit}' /etc/os-release)
        os_name=$(awk -F= '$1=="PRETTY_NAME" {v=substr($0,index($0,"=")+1); gsub(/^"|"$/,"",v); print v; exit}' /etc/os-release)
    fi

    printf '\n%s\n' 'Debian 内核统一自查 v1.0.0 | 基线日期 2026-10-28'
    printf '系统：%s\n运行内核：%s\n构建信息：%s\n' "$os_name" "$release" "$build"
    printf '%s\n' '本脚本不联网、不写文件、不加载模块、不运行漏洞利用或修改防护设置。'

    local container='unknown' vm='unknown' result
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        if result=$(systemd-detect-virt --container 2>/dev/null); then
            container=$result
        else
            case "$result" in none) container='none' ;; esac
        fi
        if result=$(systemd-detect-virt --vm 2>/dev/null); then
            vm=$result
        else
            case "$result" in none) vm='none' ;; esac
        fi
    fi
    if [[ -e /.dockerenv || -e /run/.containerenv ]]; then
        [[ $container != none && $container != unknown ]] || container='container-marker'
    fi
    printf '容器检测：%s | 虚拟机检测：%s\n' "$container" "$vm"

    local kernel_pkg='' pkg_version='' pkg_source='' pkg_status='' runtime_version=''
    local record candidate
    if [[ $build =~ Debian[[:space:]]+([^[:space:]]+) ]]; then
        runtime_version=${BASH_REMATCH[1]}
    fi
    if command -v dpkg-query >/dev/null 2>&1; then
        for candidate in "linux-image-$release" "linux-image-$release-unsigned"; do
            record=$(dpkg-query -W -f='${Status}\t${Version}\t${Source}\n' "$candidate" 2>/dev/null) || continue
            IFS=$'\t' read -r pkg_status pkg_version pkg_source <<< "$record"
            if [[ $pkg_status == 'install ok installed' ]]; then
                kernel_pkg=$candidate
                # Source may include its own version in parentheses. Use the binary
                # image package Version, which is also embedded in uname -v.
                pkg_source=${pkg_source%% *}
                [[ -n $pkg_source ]] || pkg_source=$candidate
                break
            fi
        done
    fi
    printf '运行镜像对应包：%s\n包版本：%s | 源包：%s\n' \
        "${kernel_pkg:-未找到}" "${pkg_version:-未知}" "${pkg_source:-未知}"

    local trusted=1 reason='' family=''
    if [[ $os_id != debian ]]; then
        trusted=0; reason='仅核实了 Debian 官方分支，不能套用到此系统。'
    elif [[ $container != none ]]; then
        trusted=0; reason='位于容器中，或容器检测不完整；必须到宿主系统运行。'
    elif ! command -v dpkg >/dev/null 2>&1; then
        trusted=0; reason='缺少 dpkg，无法按 Debian 版本规则比较。'
    elif [[ -z $kernel_pkg || -z $runtime_version ]]; then
        trusted=0; reason='无法将运行内核关联到带 Debian 构建标记的已安装镜像。'
    elif ! dpkg --compare-versions "$runtime_version" eq "$pkg_version" 2>/dev/null; then
        trusted=0; reason='运行构建与磁盘镜像包版本不同；可能未重启或包已替换。'
    else
        case "$pkg_source" in
            linux|linux-signed-amd64|linux-signed-arm64|linux-6.12) ;;
            *) trusted=0; reason='镜像源包不属于本脚本核实的官方源包列表。' ;;
        esac
    fi
    if [[ $trusted == 1 ]]; then
        case "$os_version:$release:$pkg_version" in
            12:6.1.*:6.1.*) family='bookworm-6.1' ;;
            13:6.12.*:6.12.*) family='trixie-6.12' ;;
            12:6.12.*:6.12.*)
                # This source package's LTS build was independently verified.
                if [[ $pkg_source == linux-6.12 && $pkg_version == *'~deb12u'* ]]; then
                    family='bookworm-6.12'
                else
                    trusted=0; reason='Debian 12 的此 6.12 包来源/回移分支未纳入精确比较。'
                fi ;;
            *) trusted=0; reason='发行版与内核系列组合不在已核实的版本基线中。' ;;
        esac
    fi

    local -a cves=(CVE-2026-31431 CVE-2026-43284 CVE-2026-43500 CVE-2026-46300 CVE-2026-98432 CVE-2026-99999)
    local -a names=('Copy Fail' 'Dirty Frag / ESP' 'Dirty Frag / RxRPC' 'Fragnesia' 'TCP IPv4 UAF / MPTCP attack' 'PwnEscape')
    local -a fixed12=(6.1.170-1 6.1.170-3 6.1.170-3 6.1.174-1 6.1.190-1 6.1.190-1)
    local -a fixed13=(6.12.85-1 6.12.86-1 6.12.86-1 6.12.90-1 6.12.113-1 6.12.113-1)
    local i baseline state fixed_count=0 below_count=0 unknown_count=0
    printf '\n%s\n' '---- 运行内核的修复基线（不使用“最新已安装内核”代替）----'
    [[ $trusted == 1 ]] || printf '无法精确判定：%s\n' "$reason"
    for i in "${!cves[@]}"; do
        baseline='不适用'
        case "$family" in
            bookworm-6.1) baseline=${fixed12[$i]} ;;
            trixie-6.12) baseline=${fixed13[$i]} ;;
            bookworm-6.12) baseline='6.12.113-1~deb12u1' ;;
        esac
        if [[ $trusted != 1 ]]; then
            state='UNKNOWN'; unknown_count=$((unknown_count + 1))
        elif dpkg --compare-versions "$pkg_version" ge "$baseline" 2>/dev/null; then
            state='FIXED'; fixed_count=$((fixed_count + 1))
        else
            state='BELOW_BASELINE'; below_count=$((below_count + 1))
        fi
        printf '[%s] %s | %s | 修复基线 %s\n' "$state" "${cves[$i]}" "${names[$i]}" "$baseline"
    done
    printf '%s\n' \
        'FIXED：本机元数据与运行构建一致，达到官方修复基线；不是入侵取证结论。' \
        'BELOW_BASELINE：未达已核实基线，需更新或核实厂商补丁/热补丁；未证明可利用。' \
        'UNKNOWN：证据不足，不表示安全，也不表示已确认有漏洞。'

    printf '\n%s\n' '---- 攻击面线索（不改变上面的修复结论）----'
    if command -v sysctl >/dev/null 2>&1; then
        local key
        for key in net.mptcp.enabled net.ipv4.tcp_migrate_req; do
            if result=$(sysctl "$key" 2>/dev/null); then
                printf '%s\n' "$result"
            else
                printf '%s：不可读或此内核没有该参数。\n' "$key"
            fi
        done
    else
        printf '%s\n' '缺少 sysctl，跳过参数读取。'
    fi

    local ss_rc
    if command -v ss >/dev/null 2>&1; then
        if command -v timeout >/dev/null 2>&1; then
            result=$(timeout 8 ss -H -M -l -n -p 2>&1); ss_rc=$?
        else
            result=$(ss -H -M -l -n -p 2>&1); ss_rc=$?
        fi
        if [[ $ss_rc != 0 ]]; then
            printf 'MPTCP 监听：UNKNOWN（查询失败，退出码 %s）。\n%s\n' "$ss_rc" "$result"
        elif [[ -n $result ]]; then
            printf 'MPTCP 查询输出（若含错误/警告需人工复核；实际监听记录需核查可达性）：\n%s\n' "$result"
        else
            printf '%s\n' 'MPTCP 监听：当前命名空间未查到记录；不等于内核已修复。'
        fi
        printf '%s\n' 'TCP 监听：'
        if command -v timeout >/dev/null 2>&1; then
            timeout 8 ss -t -l -n -p 2>&1 || printf '%s\n' 'TCP 查询未完成。'
        else
            ss -t -l -n -p 2>&1 || printf '%s\n' 'TCP 查询未完成。'
        fi
    else
        printf '%s\n' '缺少 ss，监听检查为 UNKNOWN。'
    fi
    [[ $EUID == 0 ]] || printf '%s\n' '当前非 root，其他用户的进程信息可能不完整。'
    printf '%s\n' '监听查询仅覆盖当前网络命名空间；Docker/其他容器需在宿主机及对应命名空间另查。'
    printf '%s\n' '公网可达性还取决于云安全组、IPv4/IPv6 防火墙、NAT 和负载均衡。'

    local module livepatch_found=0
    printf '可见的相关已加载/内建模块：'
    result=''
    for module in algif_aead esp4 esp6 rxrpc; do
        [[ ! -d /sys/module/$module ]] || result+=" $module"
    done
    printf '%s\n' "${result:- 未见}"
    printf '%s\n' '模块未出现不代表不能自动加载，不能据此判定不受影响。'
    for module in /sys/kernel/livepatch/*; do
        if [[ -d $module ]]; then livepatch_found=1; break; fi
    done
    if [[ $livepatch_found == 1 ]]; then
        printf '%s\n' '发现 livepatch 条目：本脚本不核实热补丁覆盖的 CVE，低版本需另查补丁供应方。'
    fi
    printf '可见 /dev/kvm：'
    if [[ -e /dev/kvm ]]; then printf '是\n'; else printf '否\n'; fi
    printf '%s\n' 'PwnEscape：虚拟机内部无法验证云厂商宿主机是否已打补丁；需向云厂商确认。'

    printf '\n%s\n' '---- 已安装镜像包（仅供排查“安装了但未启动”）----'
    if command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W -f='${binary:Package}\t${Version}\t${Status}\n' 'linux-image-[0-9]*' 2>/dev/null |
            awk -F '\t' '$3=="install ok installed" {print $1 "  " $2; found=1} END {if (!found) print "未找到可用记录。"}'
    else
        printf '%s\n' '无 dpkg-query。'
    fi

    printf '\n修复基线汇总：FIXED=%s  BELOW_BASELINE=%s  UNKNOWN=%s\n' "$fixed_count" "$below_count" "$unknown_count"
    printf '%s\n' \
        '这是 2026-10-28 的离线规则快照，仅覆盖列出的 CVE；不检查应用漏洞或入侵历史。' \
        '对自编译、厂商内核、其他分支和热补丁，请根据供应方公告核实，不能只看版本号大小。' \
        '本机检查依赖可信的内核构建信息和软件包数据库，不验证其数字签名或防篡改状态。' \
        '每个 CVE 的依据：https://security-tracker.debian.org/tracker/<CVE-ID>'
    if [[ $below_count -gt 0 ]]; then
        printf '%s\n' '建议：核查官方安全更新，安装修复内核，并在维护窗口重启后复查。'
        return 1
    elif [[ $unknown_count -gt 0 ]]; then
        return 2
    fi
    return 0
}

# Entry point last: works with bash FILE, bash -s, or a complete curl stream.
audit_main "$@"
