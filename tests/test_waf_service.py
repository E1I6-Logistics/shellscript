"""서비스 생성/제어 인자만 검사. 실제 systemd·APT·ROS는 실행하지 않는다."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('waf_service', ROOT/'scripts/waffle/service.py')
service = importlib.util.module_from_spec(spec)
spec.loader.exec_module(service)


class WafServiceTests(unittest.TestCase):
    def test_pi_and_jetson_have_only_their_processes_and_graceful_group_stop(self):
        self.assertEqual(service.units('pi'), ['logitle-waf-bringup.service', 'logitle-waf-camera.service'])
        self.assertEqual(service.units('jetson'), ['logitle-waf-nav2.service', 'logitle-waf-pallet.service', 'logitle-waf-zenoh.service'])
        for role, components in service.COMPONENTS.items():
            for component in components:
                with self.subTest(role=role, component=component):
                    text = service.render(role, component, env={})
                    for expected in ('KillSignal=SIGINT', 'KillMode=control-group', 'TimeoutStopSec=45', 'Restart=on-failure', 'WantedBy=default.target'):
                        self.assertIn(expected, text)
                    self.assertIn(f'"{role}" "{component}"', text)
                    self.assertNotIn('wafgoal', text)
        self.assertIn('After=network-online.target logitle-waf-nav2.service', service.render('jetson', 'pallet', env={}))

    def test_settings_are_quoted_and_install_only_writes_requested_units(self):
        text = service.render('jetson', 'zenoh', root=Path('/tmp/project 100%'), env={'ZENOH_ROUTER_IP': '192.168.0.29', 'WAF_WS': '/tmp/waffle space'})
        self.assertIn('100%%', text)
        self.assertIn('Environment="ZENOH_ROUTER_IP=192.168.0.29"', text)
        self.assertIn('Environment="WAF_WS=/tmp/waffle space"', text)
        self.assertIn('WorkingDirectory=/tmp/waffle space\n', text)
        with self.assertRaises(ValueError): service.quote('bad\nline')
        with tempfile.TemporaryDirectory() as tmp, patch.object(Path, 'home', return_value=Path(tmp)), patch.object(service.subprocess, 'run') as run:
            service.install('pi')
            paths = sorted(p.name for p in (Path(tmp)/'.config/systemd/user').iterdir())
            self.assertEqual(paths, service.units('pi'))
            run.assert_called_once_with(['systemctl', '--user', 'daemon-reload'], check=True)

    def test_start_stop_and_logs_control_only_the_selected_role(self):
        for action in ('start', 'stop', 'restart', 'enable', 'disable', 'status'):
            with self.subTest(action=action), patch('sys.argv', ['waf_service', action, '--role', 'pi']), patch.object(service.subprocess, 'run') as run:
                run.return_value.returncode = 0
                self.assertEqual(service.main(), 0)
                self.assertEqual(run.call_args.args[0], ['systemctl', '--user', '--no-pager', action]+service.units('pi'))
        with patch('sys.argv', ['waf_service', 'logs', '--role', 'jetson', '--follow']), patch.object(service.subprocess, 'run') as run:
            run.return_value.returncode = 0
            service.main()
            command = run.call_args.args[0]
            self.assertIn('--follow', command)
            self.assertNotIn('logitle-waf-bringup.service', command)


if __name__ == '__main__': unittest.main()
