#!/usr/bin/env bash
# 기존 WAF 작업 공간·지도·모델 보존. 하드웨어 프로세스 실행 없음.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
role="${WAF_ROLE:-}"
env_only=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --role) role="${2:?--role pi 또는 jetson 필요}"; shift 2 ;;
        --env-only) env_only=true; shift ;;
        *) echo '사용법: bash scripts/waffle/install.sh --role pi|jetson [--env-only]' >&2; exit 1 ;;
    esac
done
case "$role" in pi|jetson) ;; *) echo '[WAF] --role pi 또는 --role jetson 필요' >&2; exit 1 ;; esac
[ -r /opt/ros/jazzy/setup.bash ] || { echo '[WAF] ROS 2 Jazzy를 먼저 설치하세요.' >&2; exit 1; }
if [ "$env_only" = false ]; then
    sudo apt update
    sudo apt install -y ros-jazzy-rmw-cyclonedds-cpp
    if [ "$role" = jetson ]; then
        sudo apt install -y curl gnupg
        sudo install -d -m 0755 /etc/apt/keyrings
        curl -fsSL https://download.eclipse.org/zenoh/debian-repo/zenoh-public-key \
            | sudo gpg --dearmor --yes --output /etc/apt/keyrings/zenoh-public-key.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/zenoh-public-key.gpg] https://download.eclipse.org/zenoh/debian-repo/ /' \
            | sudo tee /etc/apt/sources.list.d/zenoh.list >/dev/null
        sudo apt update
        sudo apt install -y zenoh-bridge-ros2dds=1.9.0 --allow-downgrades
        sudo apt-mark hold zenoh-bridge-ros2dds
    fi
fi
bash "$SCRIPT_DIR/../robot/configure_shell.sh" --role "$role"
echo "[WAF] $role 등록 완료 · source ~/.bashrc 실행 후 robot_info 확인"
echo '[WAF] Domain 11 / CycloneDDS / SUBNET. 기존 실행 노드에는 재시작 후 적용됩니다.'
if [ "$role" = pi ]; then
    echo '[WAF] Pi: Zenoh 없이 wafbring / wafcamera 사용'
else
    echo '[WAF] Jetson: wafnav2 / wafreplace / logizenoh <FMS_IP>를 각각 별도 터미널에서 실행'
fi
