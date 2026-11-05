# shellscript

Logistics 프로젝트에서 사용하는 **Ubuntu 24.04 / ROS 2 Jazzy / Zenoh 환경 설정 및 실행 보조 스크립트** 모음입니다. 메인 PC(FMS)와 TurtleBot3 로봇의 패키지 설치, ROS 2 통신 모드 전환, 자주 사용하는 실행 명령 및 Wi-Fi 설정을 지원합니다.

## 1. 폴더 구조

```text
shellscript/
├── logitlebash.sh                  # TurtleBot3 공통 ROS2 환경 및 실행 함수
├── scripts/
│   ├── main/
│   │   ├── install_main.sh         # 메인 PC용 Zenoh 및 ROS 패키지 설치
│   │   ├── requirements.txt        # 메인 PC APT 패키지 목록
│   │   └── bashrc_main.conf       # 메인 PC ROS 통신 환경 설정
│   ├── robot/
│   │   ├── install_robot.sh        # 로봇용 Zenoh Bridge 및 ROS 패키지 설치
│   │   ├── requirements.txt        # 로봇 APT 패키지 목록
│   │   └── bashrc_robot.conf      # 로봇별 ROS 통신 환경 설정
│   ├── setup.sh                    # FMS 프로젝트 통합 설치용 스크립트
│   └── verify_env.sh               # FMS 환경 확인용 스크립트
├── setup_wifi.sh                   # NetworkManager 기반 Wi-Fi 연결/고정 IP
├── setup_wifi_static.sh            # Netplan 기반 Wi-Fi 고정 IP 설정
└── set_wifi_static.sh              # 구형 Netplan 고정 IP 스크립트
```

## 2. 준비 환경

- Ubuntu 24.04, ROS 2 Jazzy
- TurtleBot3 Burger: 로봇용 패키지, LDS 드라이버 및 [Logistics_AMR](https://github.com/E1I6-Logistics/Logistics_AMR) 워크스페이스 별도 준비
- 메인 PC: [Logistics_AI](https://github.com/E1I6-Logistics/Logistics_AI) 별도 준비
- Zenoh Router는 메인 PC, `zenoh-bridge-ros2dds`는 로봇 측에서 사용

```bash
git clone -b dev https://github.com/E1I6-Logistics/shellscript.git ~/shellscript
cd ~/shellscript
```

## 3. 설치

### 로봇 (TurtleBot3)

**ROS 2 Jazzy가 이미 설치된 로봇**에서 실행합니다. `zenoh-bridge-ros2dds` **1.9.0**과 필요한 RMW 패키지 등을 설치하고 Zenoh 패키지 버전을 고정합니다.

```bash
cd ~/shellscript
bash scripts/robot/install_robot.sh
```

실행 전에 스크립트 내용을 확인하세요. APT 저장소 등록과 `sudo apt install`, 버전 고정(`apt-mark hold`)이 실행됩니다.

### 메인 PC

**ROS 2 Jazzy가 이미 설치된 Ubuntu 24.04 PC**에서 실행합니다. Zenoh Router와 ROS2DDS Bridge **1.9.0**을 설치합니다.

```bash
cd ~/shellscript
bash scripts/main/install_main.sh
```

`scripts/setup.sh`는 이 `shellscript` 폴더 단독 설치용이 아닙니다. `backend/requirements.txt`, `frontend/`, `start_fms.sh` 등이 **같은 프로젝트 루트**에 있다고 가정하므로, 단독 clone 직후 이 스크립트를 실행하지 마세요. FMS 통합 설치는 FMS 프로젝트 폴더 구조에 맞게 사용해야 합니다.

## 4. 로봇 환경 설정 및 실행

현재 실장비에서 사용하는 공통 스크립트는 `logitlebash.sh`입니다.

```bash
# 최초 한 번 ~/.bashrc에 등록
printf '\nsource ~/shellscript/logitlebash.sh\n' >> ~/.bashrc
source ~/.bashrc
```

> 중복 등록하지 않도록 `grep -n 'logitlebash.sh' ~/.bashrc`로 먼저 확인하세요. AMR 프로필은 `~/logitle_ws`, `~/turtlebot3_ws`를 사용합니다. WAF Pi·Jetson 경로는 아래 전용 절차를 참고하세요.

주요 명령은 다음과 같습니다.

| 명령 | 역할 |
| --- | --- |
| `ros_local` | AMR1~3: Domain 0·LOCALHOST / WAF Pi·Jetson: Domain 11·SUBNET 유지 |
| `ros_normal` | AMR1~3: Domain 30/31/32·FastDDS / WAF: Domain 11·CycloneDDS·SUBNET |
| `robot_info` | 로봇 IP, Domain, RMW, Bridge 실행 상태 확인 |
| `sl` | `~/logitle_ws/install/setup.bash` Source |
| `st` | `~/turtlebot3_ws/install/setup.bash` Source |
| `logibring` | 통합 AMR Bringup (Nav2, 도킹, ArUco 포함) |
| `loginav2` | Nav2 단독 실행 |
| `turtlebring` | TurtleBot3 기본 Bringup |
| `logizenoh` | 로봇 이름으로 Zenoh Bridge 실행, 기본 Router IP `192.168.0.16` |
| `logicam` | 카메라 Launch |
| `roskill` | 로컬 ROS/Zenoh 관련 프로세스 강제 종료 (**주의**) |

AMR1~3을 FMS와 연결하는 실행 예시 (WAF는 아래 전용 절차 사용, 각각 **별도 터미널**):

```bash
# Terminal 1: 로봇 구동·Nav2·ArUco·도킹
ros_local
sl
logibring
```

```bash
# Terminal 2: Zenoh Bridge
ros_local
sl
logizenoh
```

`logizenoh`는 `turtlebot1`, `turtlebot2`, `turtlebot3`, `waffle`을 지원합니다. AMR에서는 내부적으로 `ros2 launch zenoh_pkg zenoh.launch.py`를 사용하며, `robot_id`와 Router 주소 `192.168.0.16`이 설정되어 있습니다. Waffle에서는 아래 전용 Bridge 설정을 사용합니다. **메인 PC IP가 다르면 `logitlebash.sh`의 `logizenoh` 부분을 수정하거나 아래처럼 직접 실행**하세요.

```bash
ros2 launch zenoh_pkg zenoh.launch.py robot_id:=robot3 router_ip:=<메인_PC_IP>
```

Zenoh Router는 TCP **7447** 포트를 사용합니다. 메인 PC에서 Router가 먼저 구동 중이어야 합니다. AMR1~3은 `ros_local`을 사용합니다. WAF의 Jetson Bridge는 Domain 11·SUBNET을 사용합니다.

### 메인 PC 환경 설정(선택)

`scripts/main/bashrc_main.conf`를 확인한 후 별도 파일로 로드할 수 있습니다.

```bash
cp ~/shellscript/scripts/main/bashrc_main.conf ~/.axbashrc
printf '\nsource ~/.axbashrc\n' >> ~/.bashrc
source ~/.bashrc
```

메인 PC 설정의 `ros_local`은 로봇과 달리 **Domain 15**를 사용합니다. `main_info`로 현재 IP와 ROS 환경을 확인할 수 있습니다. 이미 `.bashrc`에 설정이 있다면 중복 등록하지 마세요.

## 5. Wi-Fi 설정 스크립트

| 파일 | 용도 |
| --- | --- |
| `setup_wifi.sh` | `nmcli`로 SSID 연결, 선택적으로 IPv4 고정 IP 설정 |
| `setup_wifi_static.sh` | Netplan 파일 백업 후 고정 IP·게이트웨이·DNS 설정 |
| `set_wifi_static.sh` | 구형 Netplan 스크립트. 네트워크 설정을 덮어쓰므로 사용 비권장 |

NetworkManager(`nmcli`)를 사용하는 장비라면:

```bash
sudo bash setup_wifi.sh
```

Netplan으로 고정 IP를 적용할 경우에는 먼저 스크립트에서 사용하는 네트워크 렌더러와 `/etc/netplan/50-cloud-init.yaml` 경로가 실제 시스템과 맞는지 확인하세요.

**주의:** Wi-Fi 변경 과정에서 현재 SSH 연결이 끊길 수 있습니다. 반드시 로컬 콘솔 또는 복구 가능한 접속 수단을 확보한 뒤 적용하세요. `set_wifi_static.sh`에는 기존 Wi-Fi 자격 정보가 포함되어 있으므로 공개 저장소에 보관하지 말고 제거·교체해야 합니다. 이미 노출된 자격 정보는 변경하는 것이 안전합니다.

---


## Waffle Pi + AX Jetson (robot4)

```text
Waffle Pi 192.168.0.105                      AX Jetson 192.168.0.100
bringup · 카메라 매니저  ← DDS Domain 11 →  Nav2 · 비전 · pallet_replace
CycloneDDS / SUBNET                         CycloneDDS / SUBNET
Zenoh 설치·실행 없음                         Zenoh Bridge → FMS Router
                                             외부 네임스페이스 /robot4
```

**두 장비 모두 Domain 11, CycloneDDS, SUBNET을 유지한다.** `ROS_LOCALHOST_ONLY`는 해제한다.
WAF 프로필에서는 실수로 `ros_local`을 호출해도 Domain 0·LOCALHOST로 전환하지 않는다.
AMR1~3의 기존 모드와 FMS 설정은 변경하지 않는다.

### 최초 설치·등록

ROS 2 Jazzy와 기존 WAF·카메라 작업 공간이 설치·빌드된 상태를 전제로 한다.
이 설치기는 통신 패키지와 셸 명령만 준비한다. 모델·지도·Nav2 파라미터를 수정하거나
로봇·카메라·액션·Bridge를 자동 실행하지 않는다.

두 장비에 저장소가 없으면 각각:

```bash
git clone -b dev https://github.com/E1I6-Logistics/shellscript.git ~/shellscript
```

이미 있으면 `~/shellscript`에서 `git switch dev` 후 `git pull --ff-only origin dev`로 갱신한다.
작업 중인 변경이 있으면 먼저 보존한다.

Waffle Pi (`waffle@192.168.0.105`):

```bash
cd ~/shellscript
bash scripts/waffle/install.sh --role pi
unset WAF_WS
source ~/.bashrc
robot_info
```

AX Jetson (`ax_logistics@192.168.0.100`):

```bash
cd ~/shellscript
bash scripts/waffle/install.sh --role jetson
unset WAF_WS
source ~/.bashrc
robot_info
```

Pi는 CycloneDDS만 설치한다. Jetson은 CycloneDDS와 `zenoh-bridge-ros2dds` 1.9.0을 설치한다.
이미 패키지가 설치되어 있으면 `--env-only`를 추가해 환경 등록만 진행할 수 있다.
`.bashrc`를 백업하고 관리 블록을 한 번만 등록한다. `--role jetson`은 호스트명이
`localhost.localdomain`이어도 적용된다. 계정명 `ax_logistics`도 자동 인식한다.

### 실행: 각각 별도 터미널

SSH에서 `.bashrc`의 비대화형 조기 종료에 영향을 받지 않도록 환경 파일을 직접 읽는다.
아래 따옴표는 셸용 ASCII 작은따옴표다.

Waffle bringup:

```bash
ssh -t waffle@192.168.0.105 'source ~/shellscript/logitlebash.sh && wafbring'
```

Waffle 카메라 매니저:

```bash
ssh -t waffle@192.168.0.105 'source ~/shellscript/logitlebash.sh && wafcamera'
```

Jetson Nav2:

```bash
ssh -t ax_logistics@192.168.0.100 'source ~/shellscript/logitlebash.sh && wafnav2'
```

Jetson 비전·팔레트 액션 서버:

```bash
ssh -t ax_logistics@192.168.0.100 'source ~/shellscript/logitlebash.sh && wafreplace'
```

Jetson Zenoh Bridge (FMS Router를 먼저 실행, 주소가 다르면 변경):

```bash
ssh -t ax_logistics@192.168.0.100 'source ~/shellscript/logitlebash.sh && logizenoh 192.168.0.16'
```

**Pi에서 `logizenoh`를 실행하면 시작하지 않고 Jetson에서 실행하라는 안내를 표시한다.**

### 전원 ON 자동 시작과 종료·재실행

먼저 수동 SSH 터미널에서 실행하던 bringup·카메라·Nav2·액션·Bridge를 Ctrl+C로 종료한다.
같은 프로그램을 수동 실행과 서비스로 중복 시작하지 않는다.
Pi에 예전 Zenoh Bridge가 실행 중이면 종료하고 이후에는 Jetson에서만 실행한다.

두 장비에서 위 역할 등록을 마친 뒤 **각 장비에서 한 번씩** 실행한다:

```bash
source ~/.bashrc
sudo loginctl enable-linger "$(id -un)"
waf_service autostart
waf_service status
```

로그아웃하거나 전원을 다시 넣어도 사용자 systemd가 실행한다.
Pi는 bringup·카메라 매니저 2개, Jetson은 Nav2·팔레트 액션 서버·Zenoh 3개를 시작한다.
카메라 매니저는 기존 요청 방식으로 동작하고, 액션 서버는 goal을 기다린다.
자동 시작 시 `wafgoal`을 보내지는 않는다. FMS Router가 늦게 켜져도 Bridge는 연결을 시도한다.
오류 종료는 5초 뒤 재시작하며, 종료 시 프로세스 그룹에 SIGINT를 보내 정리한다.

```bash
waf_service stop           # 현재 장비의 WAF 서비스 전체 종료
waf_service start          # 다시 실행
waf_service restart        # 종료 후 다시 실행
waf_service status         # 역할에 해당하는 서비스 상태
waf_service logs --follow  # 실시간 로그 (Ctrl+C는 로그 보기만 종료)
waf_service disable       # 다음 부팅 자동 시작 해제
waf_service enable        # 다음 부팅 자동 시작 등록
```

`stop`은 다음 부팅 자동 시작 설정을 유지한다. 계속 꺼두려면 `stop`과 `disable`을 둘 다 실행한다.
FMS IP나 작업 공간 변수를 바꾸면 `waf_service install` 후 `waf_service restart`로 적용한다.
서비스는 `~/.config/systemd/user/logitle-waf-*.service`에 등록되며 기존 OMX·AMR 서비스는 관리하지 않는다.

### 기본 경로와 단축 명령

| 장비 | 명령 | 실행 대상 |
|---|---|---|
| Pi | `wafbring` | `~/Logistics_WAF_RASPI/install/setup.bash` → `waffle waffle_bringup.launch.py` |
| Pi | `wafcamera` | `~/camera_ws/install/setup.bash` → `~/camera_ws/scripts/waffle_camera_manager.py` |
| Jetson | `wafnav2` | `~/Logistics_WAF`의 지도·keepout·`config/waffle_real_nav.yaml`로 Nav2 실행 |
| Jetson | `wafreplace` | `~/venv/yolov3/bin/python ~/Logistics_WAF/src/pallet_replace_server.py` |
| Jetson | `logizenoh [FMS_IP]` | DDS Domain 11·SUBNET ↔ Zenoh `/robot4` |
| 공통 | `wafnetwork` | Domain 11·CycloneDDS·SUBNET 재적용, localhost 제한 해제 |
| 공통 | `robot_info` | 적용된 ID·역할·Domain·RMW 확인 |

`WAF_WS`, `WAF_CAMERA_WS`, `WAF_PYTHON`, `WAF_MAP`, `WAF_MASK`, `WAF_NAV_PARAMS`로
기본 경로를 바꿀 수 있다. 기존 셸에 예전 `WAF_WS=~/turtlebot3_ws`가 남아 있다면
새 SSH 터미널을 열거나 `unset WAF_WS` 후 환경을 다시 읽는다.
기존 실행 노드는 환경변수를 바꿔도 옮겨지지 않으므로 작업을 종료하고 이 환경에서 다시 시작한다.
조회가 오래된 daemon 환경을 사용하면 해당 장비에서 `ros2 daemon stop` 후 다시 조회한다.

### 직접 액션 시험

Jetson에서 서버가 보이는지 확인:

```bash
ros2 action list -t
ros2 topic list
```

Jetson에 접속해 **실제 팔레트 교체**를 요청:

```bash
ssh -t ax_logistics@192.168.0.100 'source ~/shellscript/logitlebash.sh && wafgoal 1'
```

`wafgoal 1`은 기존 `/pallet_replace` 액션에 `{destination: 1}`을 보내고 피드백을 표시한다.
다른 PC에서 직접 액션을 보내려면 그 PC에도 동일한 `waffle_interfaces`를 빌드·source하고
Domain 11·CycloneDDS·SUBNET을 적용한다.

### Bridge 설정 범위

기존 `scripts/waffle/bridge.json5`를 그대로 사용한다. 외부 FMS에는
`/robot4/battery_state`, `/robot4/amcl_pose`, `/robot4/logitle_pose`,
`/robot4/pallet_replace`만 연결한다. Waffle·Jetson 내부의 `/scan`, `/tf`, 카메라,
Nav2·속도 제어 이름에는 `/robot4`를 붙이지 않는다.

개발 검증: `python3 -m unittest discover -s tests -v`.
실제 장비·APT·ROS 실행 없이 셸 환경, 역할 분리, 기존 AMR1~3 동작을 검증한다.
