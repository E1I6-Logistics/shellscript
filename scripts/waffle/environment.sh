#!/usr/bin/env bash
# logitlebash.sh가 hostname=waffle일 때만 읽는다. 하드웨어 프로세스는 시작하지 않는다.
_LOGITLE_WAF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WAF_WS="${WAF_WS:-$HOME/turtlebot3_ws}"
export ROBOT_ID=robot4
export ROBOT_DOMAIN_ID=11
export ROS_DOMAIN_ID=11
export LDS_MODEL=LDS-03
export TURTLEBOT3_MODEL=waffle
export OPENCR_MODEL=waffle
export OPENCR_PORT=/dev/ttyACM0
export LOGITLE_MAP="$WAF_WS/map/logitle_map_fin.yaml"
export LOGITLE_MASK="$WAF_WS/map/logitle_map_fin_keepout.yaml"

wafsource() {
    if [ ! -r "$WAF_WS/install/setup.bash" ]; then
        echo "[WAF] 워크스페이스를 먼저 빌드하세요: $WAF_WS/install/setup.bash"
        return 1
    fi
    source "$WAF_WS/install/setup.bash"
    export LDS_MODEL=LDS-03 TURTLEBOT3_MODEL=waffle OPENCR_MODEL=waffle OPENCR_PORT=/dev/ttyACM0
}

# 새 셸에서 기존 Waffle 작업 공간을 읽는다. 미빌드는 경고만 표시한다.
if [ -r "$WAF_WS/install/setup.bash" ]; then
    wafsource
else
    echo "[WAF] 환경만 등록됨 · 작업 공간 미빌드: $WAF_WS"
fi

wafbring() {
    ros2 launch turtlebot3_bringup robot.launch.py "$@"
}

wafnav2() {
    ros2 launch turtlebot3_navigation2 navigation2.launch.py \
        use_sim_time:=false map:="$LOGITLE_MAP" mask:="$LOGITLE_MASK" \
        params_file:="$WAF_WS/config/waffle_real_nav.yaml" "$@"
}

wafreplace() {
    if [ ! -r "$WAF_WS/src/pallet_replace_server.py" ]; then
        echo "[WAF] 액션 서버 파일 없음: $WAF_WS/src/pallet_replace_server.py"
        return 1
    fi
    "${WAF_PYTHON:-python3}" "$WAF_WS/src/pallet_replace_server.py" "$@"
}

# Waffle 내부 토픽은 그대로 두고 Zenoh 외부에만 /robot4로 노출한다.
waf_zenoh() {
    if [ "${ROS_DOMAIN_ID:-}" != 0 ] || \
       [ "${RMW_IMPLEMENTATION:-}" != rmw_cyclonedds_cpp ] || \
       [ "${ROS_AUTOMATIC_DISCOVERY_RANGE:-}" != LOCALHOST ]; then
        echo '[WAF] 먼저 이 터미널에서 ros_local을 실행하세요.'
        return 1
    fi
    if ! command -v zenoh-bridge-ros2dds >/dev/null 2>&1; then
        echo '[WAF] Zenoh Bridge 미설치 · bash scripts/robot/install_robot.sh 실행 필요'
        return 1
    fi
    local router_ip="${1:-${ZENOH_ROUTER_IP:-192.168.0.16}}"
    if [ "$#" -gt 0 ]; then shift; fi
    echo "[WAF] robot4 · Domain 0 · Router tcp/${router_ip}:7447"
    zenoh-bridge-ros2dds -c "$_LOGITLE_WAF_DIR/bridge.json5" \
        -d "$ROS_DOMAIN_ID" -n /robot4 \
        --ros-automatic-discovery-range "$ROS_AUTOMATIC_DISCOVERY_RANGE" \
        -e "tcp/${router_ip}:7447" client "$@"
}

# 공통 명령도 Waffle에서는 WAF 작업 공간과 실행 파일을 사용한다.
alias sl='wafsource'
alias loginav2='wafnav2'
alias logibring='wafbring'
