"""가짜 hostname/ROS/Bridge와 임시 bashrc만 사용한다. 실제 설치/로봇 실행 없음."""
import importlib.util
import json
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('configure_shell', ROOT/'scripts/robot/configure_shell.py')
configure = importlib.util.module_from_spec(spec);spec.loader.exec_module(configure)


class RobotEnvironmentTests(unittest.TestCase):
    def shell(self, host, body, template=False, user='tester', role=None):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            workspace = tmp/'waffle ws';(workspace/'install').mkdir(parents=True)
            (workspace/'install/setup.bash').write_text('# fake workspace\n')
            (workspace/'src').mkdir();(workspace/'config').mkdir();(workspace/'map').mkdir()
            (workspace/'src/pallet_replace_server.py').write_text('# fake server\n')
            (workspace/'scripts').mkdir();(workspace/'scripts/waffle_camera_manager.py').write_text('# fake camera\n')
            for name in ('logitle_map_fin.yaml','logitle_map_fin_keepout.yaml'):
                (workspace/'map'/name).write_text('fake map\n')
            (workspace/'config/waffle_real_nav.yaml').write_text('fake config\n')
            python=tmp/'fake python'
            python.write_text('#!/bin/sh\nprintf "PYTHON %s\\n" "$*" >> "$CAPTURE"\n')
            python.chmod(0o755)
            capture = tmp/'calls'
            script = r'''set -e
hostname() { if [ "${1:-}" = -I ]; then echo 127.0.0.1; else echo "$TEST_HOST"; fi; }
id() { if [ "${1:-}" = -un ]; then echo "$TEST_USER"; else command id "$@"; fi; }
source() {
    if [[ "$1" = /opt/ros/* || "$1" = "$WAF_WS/install/setup.bash" || "$1" = ~/turtlebot3_ws/install/setup.bash ]]; then return 0; fi
    builtin source "$@"
}
ros2() { printf 'ROS %s\n' "$*" >> "$CAPTURE"; }
python3() { printf 'CAMERA %s\n' "$*" >> "$CAPTURE"; }
zenoh-bridge-ros2dds() { printf 'BRIDGE %s\n' "$*" >> "$CAPTURE"; }
shopt -s expand_aliases
alias ros_local='echo OLD_LOCAL'
alias ros_normal='echo OLD_NORMAL'
alias roskill='echo OLD_KILL'
builtin source "$PROFILE"
'''+body
            env = __import__('os').environ.copy()
            env.pop('WAF_ROLE',None)
            if role:env['WAF_ROLE']=role
            env.update(TEST_HOST=host,TEST_USER=user,WAF_WS=str(workspace),WAF_CAMERA_WS=str(workspace),WAF_PYTHON=str(python),CAPTURE=str(capture),
                       PROFILE=str(ROOT/('scripts/robot/bashrc_robot.conf' if template else 'logitlebash.sh')))
            result = subprocess.run(['bash','--noprofile','--norc','-c',script],env=env,text=True,capture_output=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            return result.stdout, capture.read_text() if capture.exists() else ''

    def test_waffle_model_domain_source_and_info(self):
        self.shell('waffle', r'''
[[ "$ROBOT_ID" = robot4 && "$ROBOT_DOMAIN_ID" = 11 && "$ROS_DOMAIN_ID" = 11 ]]
[[ "$LDS_MODEL" = LDS-03 && "$TURTLEBOT3_MODEL" = waffle && "$OPENCR_MODEL" = waffle && "$OPENCR_PORT" = /dev/ttyACM0 ]]
[[ "$RMW_IMPLEMENTATION" = rmw_cyclonedds_cpp && "$ROS_AUTOMATIC_DISCOVERY_RANGE" = SUBNET ]]
robot_info
''')

    def test_pi_keeps_domain_11_and_refuses_bridge(self):
        stdout,calls=self.shell('waffle',r'''
if logizenoh; then exit 20; fi
ros_local
[[ "$ROS_DOMAIN_ID" = 11 && "$RMW_IMPLEMENTATION" = rmw_cyclonedds_cpp && "$ROS_AUTOMATIC_DISCOVERY_RANGE" = SUBNET ]]
if logizenoh 192.168.0.16; then exit 21; fi
ros_normal
[[ "$ROS_DOMAIN_ID" = 11 && "$RMW_IMPLEMENTATION" = rmw_cyclonedds_cpp && "$ROS_AUTOMATIC_DISCOVERY_RANGE" = SUBNET ]]
''')
        self.assertNotIn('BRIDGE ',calls)

    def test_ax_username_and_explicit_role_work_without_hostname_change(self):
        for user,role in (('ax_logistics',None),('another_account','jetson')):
            with self.subTest(user=user):
                self.shell('localhost.localdomain',r'''
builtin source "$PROFILE"
[[ "$WAF_ROLE" = jetson && "$ROBOT_ID" = robot4 && "$ROS_DOMAIN_ID" = 11 ]]
[[ "$RMW_IMPLEMENTATION" = rmw_cyclonedds_cpp && "$ROS_AUTOMATIC_DISCOVERY_RANGE" = SUBNET ]]
[[ -z "${ROS_LOCALHOST_ONLY:-}" ]]
''',user=user,role=role)

    def test_jetson_bridge_uses_domain_11_subnet_and_existing_config(self):
        _,calls=self.shell('localhost.localdomain',r'''
export ROS_DOMAIN_ID=0 ROS_LOCALHOST_ONLY=1
if logizenoh; then exit 20; fi
ros_local
[[ "$ROS_DOMAIN_ID" = 11 && -z "${ROS_LOCALHOST_ONLY:-}" ]]
logizenoh 192.168.0.16
''',user='ax_logistics')
        self.assertEqual(calls.count('BRIDGE '),1)
        for text in ('-d 11','-n /robot4','--ros-automatic-discovery-range SUBNET','tcp/192.168.0.16:7447','scripts/waffle/bridge.json5'):
            self.assertIn(text,calls)

    def test_user_launch_commands_and_role_guards(self):
        _,pi=self.shell('waffle',r'''
wafbring
wafcamera
if wafnav2; then exit 20; fi
if wafreplace; then exit 21; fi
''')
        self.assertIn('launch waffle waffle_bringup.launch.py',pi)
        self.assertIn('scripts/waffle_camera_manager.py',pi)
        _,jetson=self.shell('localhost.localdomain',r'''
export ROS_DOMAIN_ID=0
wafnav2
[[ "$ROS_DOMAIN_ID" = 11 ]]
wafreplace
if wafbring; then exit 20; fi
if wafgoal nope; then exit 21; fi
wafgoal 1
''',user='ax_logistics')
        for text in ('turtlebot3_navigation2 navigation2.launch.py','logitle_map_fin.yaml','logitle_map_fin_keepout.yaml','waffle_real_nav.yaml','src/pallet_replace_server.py','action send_goal /pallet_replace waffle_interfaces/action/PalletReplace {destination: 1} --feedback'):
            self.assertIn(text,jetson)

    def test_turtlebot_123_profiles_and_existing_zenoh_launch_are_preserved(self):
        for number,domain in ((1,30),(2,31),(3,32)):
            with self.subTest(robot=number):
                _,calls=self.shell('turtlebot'+str(number),f'''
[[ "$ROBOT_ID" = robot{number} && "$ROS_DOMAIN_ID" = {domain} && "$TURTLEBOT3_MODEL" = burger ]]
ros_local
logizenoh
ros_normal
[[ "$ROS_DOMAIN_ID" = {domain} && "$TURTLEBOT3_MODEL" = burger ]]
''')
                self.assertIn(f'launch zenoh_pkg zenoh.launch.py robot_id:=robot{number}',calls)
                self.assertNotIn('BRIDGE ',calls)

    def test_legacy_template_also_selects_waffle(self):
        self.shell('waffle',r'''
[[ "$ROS_DOMAIN_ID" = 11 && "$TURTLEBOT3_MODEL" = waffle && "$LDS_MODEL" = LDS-03 ]]
ros_local
ros_normal
[[ "$ROS_DOMAIN_ID" = 11 ]]
''',template=True)

    def test_bridge_routes_only_pallet_action_and_observation(self):
        data=json.loads((ROOT/'scripts/waffle/bridge.json5').read_text())
        allow=data['plugins']['ros2dds']['allow']
        self.assertEqual(allow['action_servers'],['^/pallet_replace$'])
        self.assertEqual(allow['subscribers'],[])
        self.assertEqual(allow['action_clients'],[])
        self.assertIn('^/battery_state$',allow['publishers'])
        self.assertIn('^/amcl_pose$',allow['publishers'])

    def test_bashrc_backup_preserves_user_lines_permissions_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'bashrc';original='export USER_SETTING=keep\nalias ros_local="old"\n'
            path.write_text(original);path.chmod(0o640)
            backup=configure.configure(ROOT/'logitlebash.sh',path)
            self.assertEqual(backup.read_text(),original)
            self.assertEqual(backup.stat().st_mode & 0o777,0o640)
            first=path.read_text();self.assertTrue(first.startswith(original))
            self.assertIsNone(configure.configure(ROOT/'logitlebash.sh',path))
            self.assertEqual(path.read_text(),first)
            self.assertEqual(path.read_text().count(configure.BEGIN),1)
            # 나중에 추가한 사용자 설정을 보존하고 관리 블록만 마지막으로 옮긴다.
            path.write_text(first+'export NEW_SETTING=also_keep\n')
            configure.configure(ROOT/'logitlebash.sh',path)
            self.assertIn('export NEW_SETTING=also_keep',path.read_text())
            self.assertTrue(path.read_text().endswith(configure.END+'\n'))

    def test_special_path_is_shell_quoted_and_missing_source_does_not_touch_bashrc(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/"env space ' quoted.sh";source.write_text('export ENV_TEST_OK=yes\n')
            path=Path(tmp)/'bashrc'
            configure.configure(source,path)
            result=subprocess.run(['bash','--noprofile','--norc','-c','source "$1"; test "$ENV_TEST_OK" = yes','bash',str(path)])
            self.assertEqual(result.returncode,0)
            before=path.read_bytes()
            with self.assertRaises(ValueError):configure.configure(Path(tmp)/'missing',path)
            self.assertEqual(path.read_bytes(),before)

    def test_explicit_role_is_saved_and_preserved_on_reconfigure(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'bashrc';path.write_text('export KEEP_ME=yes\n')
            configure.configure(ROOT/'logitlebash.sh',path,'jetson')
            self.assertIn('export WAF_ROLE=jetson',path.read_text())
            self.assertIsNone(configure.configure(ROOT/'logitlebash.sh',path))
            configure.configure(ROOT/'logitlebash.sh',path,'pi')
            self.assertIn('export WAF_ROLE=pi',path.read_text())
            self.assertNotIn('export WAF_ROLE=jetson',path.read_text())

    def test_environment_only_installer_uses_requested_file_without_apt(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'test bashrc';path.write_text('export KEEP_ME=yes\n')
            result=subprocess.run(['bash',str(ROOT/'scripts/robot/configure_shell.sh'),'--bashrc',str(path)],text=True,capture_output=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertIn('export KEEP_ME=yes',path.read_text())
            self.assertIn(str(ROOT/'logitlebash.sh'),path.read_text())
            self.assertEqual(path.read_text().count(configure.BEGIN),1)

    def test_corrupt_managed_block_is_not_overwritten_and_all_shell_files_parse(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'bashrc';path.write_text(configure.BEGIN+'\nuser content\n')
            original=path.read_bytes()
            with self.assertRaises(ValueError):configure.configure(ROOT/'logitlebash.sh',path)
            self.assertEqual(path.read_bytes(),original)
        for file in [ROOT/'logitlebash.sh', ROOT/'scripts/robot/bashrc_robot.conf', ROOT/'scripts/robot/install_robot.sh', ROOT/'scripts/robot/configure_shell.sh',ROOT/'scripts/waffle/environment.sh',ROOT/'scripts/waffle/detect_role.sh',ROOT/'scripts/waffle/install.sh']:
            self.assertEqual(subprocess.run(['bash','-n',str(file)]).returncode,0,str(file))


if __name__=='__main__':unittest.main()
