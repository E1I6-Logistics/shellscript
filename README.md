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

> 중복 등록하지 않도록 `grep -n 'logitlebash.sh' ~/.bashrc`로 먼저 확인하세요. `logitlebash.sh`의 AMR 프로필은 `~/logitle_ws`, `~/turtlebot3_ws` 구성을 사용합니다. Waffle은 아래 전용 프로필의 `~/turtlebot3_ws`만 사용합니다.

주요 명령은 다음과 같습니다.

| 명령 | 역할 |
| --- | --- |
| `ros_local` | Zenoh용 `ROS_DOMAIN_ID=0`, CycloneDDS, `LOCALHOST` 설정 |
| `ros_normal` | TurtleBot Domain `30/31/32`, Waffle Domain `11`, Fast DDS, `SUBNET` 설정 |
| `robot_info` | 로봇 IP, Domain, RMW, Bridge 실행 상태 확인 |
| `sl` | `~/logitle_ws/install/setup.bash` Source |
| `st` | `~/turtlebot3_ws/install/setup.bash` Source |
| `logibring` | 통합 AMR Bringup (Nav2, 도킹, ArUco 포함) |
| `loginav2` | Nav2 단독 실행 |
| `turtlebring` | TurtleBot3 기본 Bringup |
| `logizenoh` | 로봇 이름으로 Zenoh Bridge 실행, 기본 Router IP `192.168.0.16` |
| `logicam` | 카메라 Launch |
| `roskill` | 로컬 ROS/Zenoh 관련 프로세스 강제 종료 (**주의**) |

FMS와 연결하는 실기체 실행 예시 (각각 **별도 터미널**):

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

Zenoh Router는 TCP **7447** 포트를 사용합니다. 메인 PC에서 Router가 먼저 구동 중이어야 합니다. Bridge를 사용하는 로봇은 `ros_local` 모드를 사용하세요.

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


## Waffle(WAF / robot4) 자동 환경 설정

호스트명이 **waffle**이면 같은 저장소가 WAF 프로필을 선택합니다. 기존
TurtleBot1/2/3의 Burger 설정과 Domain 30/31/32는 유지합니다.
Git clone만으로 셸 설정이 실행되지는 않습니다. 아래 설치 또는 환경 등록을 한 번 실행하세요.

```bash
# waffle@waffle에서 실행
# 저장소가 없다면:
git clone -b dev https://github.com/E1I6-Logistics/shellscript.git ~/shellscript
cd ~/shellscript

# Zenoh/RMW까지 처음 설치하는 경우 (환경 등록도 포함)
bash scripts/robot/install_robot.sh
source ~/.bashrc
robot_info
```

Zenoh와 필요한 RMW가 이미 설치되어 있다면 패키지를 다시 설치할 필요 없이:

```bash
cd ~/shellscript
git pull --ff-only origin dev
bash scripts/robot/configure_shell.sh
source ~/.bashrc
robot_info
```

등록 스크립트는 기존 `.bashrc`를 백업하고 맨 끝의 전용 블록만 관리합니다.
재실행해도 블록이 중복되지 않습니다. 예전 `ros_local`/`ros_normal` alias가 있어도
새 함수와 충돌하지 않습니다. 실제 로봇·Nav2·보충 액션은 자동 시작하지 않습니다.

| 항목 | Waffle 설정 |
| --- | --- |
| 장비 ID / Bridge 네임스페이스 | `robot4` / `/robot4` |
| ROS / 작업 공간 | Jazzy / `~/turtlebot3_ws/install/setup.bash` |
| 모델 / OpenCR / 포트 | `waffle` / `waffle` / `/dev/ttyACM0` |
| LDS | `LDS-03` |
| 새 터미널·`ros_normal` | Domain **11**, Fast DDS, SUBNET |
| `ros_local` | Domain **0**, CycloneDDS, LOCALHOST |

FMS와 연결할 때는 **Waffle의 모든 관련 터미널**에서 `ros_local`을 사용합니다.
Domain 11로 이미 켜 둔 노드는 셸 환경만 바꿔도 Domain 0으로 이동하지 않습니다.
작업을 끝낸 뒤 해당 노드를 종료하고 같은 모드로 다시 실행해야 합니다.

```bash
# Waffle 터미널 1: 기본 로봇 bringup
ros_local
wafbring
```

```bash
# Waffle 터미널 2: FMS Router에 연결 (FMS를 먼저 실행)
ros_local
logizenoh                     # 기본 192.168.0.16:7447
# 다른 PC 주소라면: logizenoh 192.168.0.19
```

Bridge는 AMR의 `zenoh_pkg` 없이 실행됩니다. Waffle 내부의 루트 토픽을 바꾸지 않고
FMS 쪽에 `/robot4/battery_state`, `/robot4/amcl_pose`, `/robot4/logitle_pose`,
`/robot4/pallet_replace`로 노출합니다. WAF Bridge는 관측과 보충 액션만 연결하고
FMS에서 Waffle의 일반 Nav2/속도 명령을 보내는 경로는 열지 않습니다.

기존 WAF Nav2·보충 서버도 같은 `ros_local` 환경에서 실행합니다. 선택 단축 명령:

| 명령 | 역할 |
| --- | --- |
| `wafsource` 또는 `sl` | Waffle 작업 공간 source |
| `wafbring` 또는 `logibring` | Waffle 기본 bringup (Nav2는 별도) |
| `wafnav2` 또는 `loginav2` | WAF Nav2·기존 지도/keepout/config 사용 |
| `wafreplace` | 기존 `src/pallet_replace_server.py` 실행 |
| `robot_info` | 모델·LDS·장비 ID·현재 Domain/RMW 확인 |

`WAF_WS`로 작업 공간, `WAF_PYTHON`으로 보충 서버 Python을 지정할 수 있습니다.
이 저장소는 WAF 소스·모델·지도 파일을 다운로드하거나 학습하지 않습니다.
WAF 작업 공간은 기존에 빌드된 상태여야 하며 Nav2/보충 서버를 중복 실행하지 마세요.

개발 검증: `python3 -m unittest discover -s tests -v` (실제 ROS·설치·로봇 실행 없음).
