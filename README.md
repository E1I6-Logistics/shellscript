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

> 중복 등록하지 않도록 `grep -n 'logitlebash.sh' ~/.bashrc`로 먼저 확인하세요. `logitlebash.sh`는 `~/logitle_ws`, `~/turtlebot3_ws`가 존재하는 구성을 전제로 합니다.

주요 명령은 다음과 같습니다.

| 명령 | 역할 |
| --- | --- |
| `ros_local` | Zenoh용 `ROS_DOMAIN_ID=0`, CycloneDDS, `LOCALHOST` 설정 |
| `ros_normal` | 로봇별 Domain `30/31/32`, Fast DDS, `SUBNET` 설정 |
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

`logizenoh`는 로봇 호스트명이 `turtlebot1`, `turtlebot2`, `turtlebot3` 중 하나일 때 동작합니다. 내부적으로 `ros2 launch zenoh_pkg zenoh.launch.py`를 사용하며, `robot_id`와 Router 주소 `192.168.0.16`이 설정되어 있습니다. **메인 PC IP가 다르면 `logitlebash.sh`의 `logizenoh` 부분을 수정하거나 아래처럼 직접 실행**하세요.

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
