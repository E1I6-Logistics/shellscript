"""WAF Pi/Jetson의 사용자 systemd 서비스만 관리. 작업 goal은 보내지 않는다."""
import argparse
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]
COMPONENTS = {'pi': ('bringup', 'camera'), 'jetson': ('nav2', 'pallet', 'zenoh')}


def quote(value):
    value = str(value)
    if any(c in value for c in ('\n', '\r', '\0')):
        raise ValueError('서비스 설정에 줄바꿈/널 문자는 사용할 수 없습니다')
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('%', '%%') + '"'


def units(role):
    return [f'logitle-waf-{name}.service' for name in COMPONENTS[role]]


def directory_value(value):
    # WorkingDirectory는 ExecStart/Environment와 달리 따옴표를 경로 문자로 취급한다.
    quote(value)  # 줄바꿈/널 검증
    return str(value).replace('%', '%%')


def render(role, component, root=ROOT, env=None):
    if component not in COMPONENTS[role]:
        raise ValueError('역할에 맞지 않는 서비스입니다')
    env = os.environ if env is None else env
    values = {'WAF_ROLE': role}
    for key in ('WAF_WS', 'WAF_CAMERA_WS', 'WAF_PYTHON', 'WAF_MAP', 'WAF_MASK',
                'WAF_NAV_PARAMS', 'ZENOH_ROUTER_IP', 'CYCLONEDDS_URI', 'ROS_STATIC_PEERS', 'LD_LIBRARY_PATH'):
        if env.get(key):
            values[key] = env[key]
    values.setdefault('ZENOH_ROUTER_IP', '192.168.0.16')
    workspace = env.get('WAF_WS', str(Path.home() / ('Logistics_WAF_RASPI' if role == 'pi' else 'Logistics_WAF')))
    if component == 'camera':
        workspace = env.get('WAF_CAMERA_WS', str(Path.home() / 'camera_ws'))
    after = 'network-online.target'
    if component == 'camera':
        after += ' logitle-waf-bringup.service'
    elif component == 'pallet':
        after += ' logitle-waf-nav2.service'
    elif component == 'zenoh':
        after += ' logitle-waf-pallet.service'
    environment = ''.join('Environment=' + quote(k + '=' + v) + '\n' for k, v in values.items())
    return (
        '[Unit]\n'
        f'Description=LOGITLE WAF {role} {component}\n'
        f'After={after}\n'
        'StartLimitIntervalSec=0\n\n'
        '[Service]\n'
        'Type=simple\n'
        f'WorkingDirectory={directory_value(workspace)}\n'
        + environment +
        'ExecStart=/bin/bash ' + quote(root / 'scripts/waffle/run_service.sh') + ' '
        + quote(role) + ' ' + quote(component) + '\n'
        'Restart=on-failure\nRestartSec=5\n'
        'KillSignal=SIGINT\nKillMode=control-group\nTimeoutStopSec=45\n'
        'StandardOutput=journal\nStandardError=journal\n\n'
        '[Install]\nWantedBy=default.target\n'
    )


def install(role):
    directory = Path.home() / '.config/systemd/user'
    directory.mkdir(parents=True, exist_ok=True)
    for component in COMPONENTS[role]:
        path = directory / f'logitle-waf-{component}.service'
        path.write_text(render(role, component))
    subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
    print(f'[WAF] {role} 서비스 등록 완료. 아직 실행하지 않았습니다.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('install', 'autostart', 'enable', 'disable',
                                         'start', 'stop', 'restart', 'status', 'logs'))
    parser.add_argument('--role', choices=COMPONENTS, default=os.environ.get('WAF_ROLE'))
    parser.add_argument('--follow', action='store_true', help='logs 실시간 보기')
    args = parser.parse_args()
    if args.role not in COMPONENTS:
        parser.error('WAF_ROLE을 설정하거나 --role pi|jetson을 지정하세요')
    names = units(args.role)
    try:
        if args.action in ('install', 'autostart'):
            install(args.role)
            if args.action == 'install':
                return 0
        if args.action == 'logs':
            cmd = ['journalctl', '--user', '--no-pager', '-n', '60']
            for name in names:
                cmd += ['-u', name]
            if args.follow:
                cmd.append('--follow')
        else:
            action = 'enable' if args.action == 'autostart' else args.action
            cmd = ['systemctl', '--user', '--no-pager', action]
            if args.action == 'autostart':
                cmd.append('--now')
            cmd += names
        return subprocess.run(cmd, check=False).returncode
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'[WAF] 서비스 명령 실패: {error}')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
