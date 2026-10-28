import os
from pathlib import Path
import subprocess
import tempfile

SCRIPT = Path(__file__).resolve().parents[1] / 'debian-kernel-audit.sh'

def run_case(name, *, os_version='12', version='6.1.190-1',
             release='6.1.0-53-amd64', build_version=None, source='linux-signed-amd64',
             container='none', missing=False, expected=(0, 6, 0, 0), ss_fail=False,
             custom_build=False, installed_newer=False):
    with tempfile.TemporaryDirectory(prefix='kernel-audit-test-') as tmp:
        root = Path(tmp)
        bindir = root / 'bin'
        bindir.mkdir()
        osrelease = root / 'os-release'
        osrelease.write_text(f'ID=debian\nVERSION_ID="{os_version}"\nPRETTY_NAME="Debian fixture"\n')
        code = SCRIPT.read_text().replace('/etc/os-release', str(osrelease))
        code = code.replace('/.dockerenv', str(root / 'no-docker'))
        code = code.replace('/run/.containerenv', str(root / 'no-container'))
        target = root / 'audit.sh'
        target.write_text(code)
        def command(name, body):
            p = bindir / name
            p.write_text('#!/bin/bash\n' + body + '\n')
            p.chmod(0o755)
        command('uname', 'case "$1" in -r) printf "%s\\n" "$AUDIT_TEST_RELEASE";; -v) printf "%s\\n" "$AUDIT_TEST_BUILD";; esac')
        command('systemd-detect-virt', 'if [[ "$1" == --container ]]; then printf "%s\\n" "$AUDIT_TEST_CONTAINER"; [[ "$AUDIT_TEST_CONTAINER" != none ]]; else printf "kvm\\n"; fi')
        command('dpkg-query', '''
if [[ "$AUDIT_TEST_MISSING" == 1 ]]; then exit 1; fi
if [[ "$*" == *'linux-image-[0-9]*'* ]]; then
  printf 'linux-image-fixture\\t%s\\tinstall ok installed\\n' "$AUDIT_TEST_INSTALLED"
else
  printf 'install ok installed\\t%s\\t%s (signed-source-version)\\n' "$AUDIT_TEST_VERSION" "$AUDIT_TEST_SOURCE"
fi''')
        command('sysctl', 'case "$1" in net.mptcp.enabled) printf "net.mptcp.enabled = 1\\n";; *) printf "net.ipv4.tcp_migrate_req = 0\\n";; esac')
        command('ss', 'if [[ "$AUDIT_TEST_SS_FAIL" == 1 ]]; then printf "unknown option M\\n" >&2; exit 1; fi\nexit 0')
        env = dict(os.environ, PATH=str(bindir) + ':' + os.environ['PATH'],
                   AUDIT_TEST_RELEASE=release,
                   AUDIT_TEST_BUILD=('custom kernel' if custom_build else '#1 SMP Debian ' + (build_version or version) + ' (2026-10-28)'),
                   AUDIT_TEST_VERSION=version, AUDIT_TEST_SOURCE=source,
                   AUDIT_TEST_CONTAINER=container, AUDIT_TEST_MISSING=str(int(missing)),
                   AUDIT_TEST_SS_FAIL=str(int(ss_fail)),
                   AUDIT_TEST_INSTALLED='6.1.190-1' if installed_newer else version)
        result = subprocess.run(['bash', str(target)], env=env, text=True, capture_output=True, timeout=15)
        code, fixed, below, unknown = expected
        assert result.returncode == code, (name, result.returncode, result.stdout, result.stderr)
        assert f'FIXED={fixed}  BELOW_BASELINE={below}  UNKNOWN={unknown}' in result.stdout, (name, result.stdout)
        if ss_fail:
            assert 'MPTCP 监听：UNKNOWN' in result.stdout
        assert '不检查应用漏洞或入侵历史' in result.stdout
        print('PASS', name)

run_case('bookworm fixed')
run_case('bookworm vulnerable baseline', version='6.1.164-1', expected=(1, 0, 6, 0))
run_case('first fix only', version='6.1.170-1', expected=(1, 1, 5, 0))
run_case('Debian revision comparison', version='6.1.170-2', expected=(1, 1, 5, 0))
run_case('dirtyfrag fixed', version='6.1.170-3', expected=(1, 3, 3, 0))
run_case('fragnesia fixed', version='6.1.174-1', expected=(1, 4, 2, 0))
run_case('newer installed does not change running verdict', version='6.1.164-1', installed_newer=True, expected=(1, 0, 6, 0))
run_case('package overwritten without runtime change', build_version='6.1.164-1', expected=(2, 0, 0, 6))
run_case('missing image package', missing=True, expected=(2, 0, 0, 6))
run_case('container cannot verify host', container='docker', expected=(2, 0, 0, 6))
run_case('custom build unknown', custom_build=True, expected=(2, 0, 0, 6))
run_case('vendor source unknown', source='vendor-kernel', expected=(2, 0, 0, 6))
run_case('unverified series unknown', version='6.18.57-1', release='6.18.0-vendor', expected=(2, 0, 0, 6))
run_case('trixie fixed', os_version='13', release='6.12.113+deb13-amd64', version='6.12.113-1')
run_case('trixie first fix', os_version='13', release='6.12.85+deb13-amd64', version='6.12.85-1', expected=(1, 1, 5, 0))
run_case('bookworm verified alternate source', release='6.12.0-0.deb12-amd64', version='6.12.113-1~deb12u1', source='linux-6.12')
run_case('backports not guessed', release='6.12.0-bpo-amd64', version='6.12.113-1~bpo12+1', source='linux', expected=(2, 0, 0, 6))
run_case('ss failure does not claim absent listener', ss_fail=True)
help_result = subprocess.run(['bash', str(SCRIPT), '--help'], capture_output=True)
bad_result = subprocess.run(['bash', str(SCRIPT), '--invalid'], capture_output=True)
assert help_result.returncode == 0
assert bad_result.returncode == 64
stream = subprocess.run(['bash', '-s', '--', '--version'], input=SCRIPT.read_text(), text=True, capture_output=True)
assert stream.returncode == 0 and '1.0.0' in stream.stdout
print('PASS help / invalid arguments / stdin execution')
