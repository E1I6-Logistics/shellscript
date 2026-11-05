#!/usr/bin/env bash
# Pi: bringup/camera. Jetson: Nav2/vision/action/Zenoh. 환경만 등록, 자동 실행 없음.
_LOGITLE_WAF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${WAF_ROLE:-}" in
    pi) export WAF_WS="${WAF_WS:-$HOME/Logistics_WAF_RASPI}" ;;
    jetson) export WAF_WS="${WAF_WS:-$HOME/Logistics_WAF}" ;;
    *) echo '[WAF] WAF_ROLE은 pi 또는 jetson으로 지정하세요.'; return 1 ;;
esac
export WAF_CAMERA_WS="${WAF_CAMERA_WS:-$HOME/camera_ws}"
export WAF_PYTHON="${WAF_PYTHON:-$HOME/venv/yolov3/bin/python}"
export ROBOT_ID=robot4 ROBOT_DOMAIN_ID=11
export LDS_MODEL=LDS-03 TURTLEBOT3_MODEL=waffle OPENCR_MODEL=waffle OPENCR_PORT=/dev/ttyACM0
export LOGITLE_MAP="${WAF_MAP:-$WAF_WS/map/logitle_map_fin.yaml}"
export LOGITLE_MASK="${WAF_MASK:-$WAF_WS/map/logitle_map_fin_keepout.yaml}"
unalias wafnetwork wafsource wafbring wafcamera wafnav2 wafreplace wafgoal waf_zenoh waf_service zenoh_start 2>/dev/null || true

wafnetwork() {
    export ROS_DOMAIN_ID=11 RMW_IMPLEMENTATION=rmw_cyclonedds_cpp ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
    unset ROS_LOCALHOST_ONLY
}
wafnetwork
ros_local() {
    wafnetwork
    echo '[WAF] 로컬 제한 없음: Domain 11 / CycloneDDS / SUBNET 유지'
}
ros_normal() { wafnetwork; }
_waf_role() {
    if [ "$WAF_ROLE" != "$1" ]; then
        echo "[WAF] 이 명령은 $1 장비에서 실행하세요. 현재 역할: $WAF_ROLE"
        return 1
    fi
}
wafsource() {
    if [ ! -r "$WAF_WS/install/setup.bash" ]; then
        echo "[WAF] 작업 공간을 먼저 빌드하세요: $WAF_WS/install/setup.bash"
        return 1
    fi
    source /opt/ros/jazzy/setup.bash || return
    source "$WAF_WS/install/setup.bash" || return
    wafnetwork
}
if [ -r "$WAF_WS/install/setup.bash" ]; then
    wafsource
else
    echo "[WAF] 환경만 등록됨 · 작업 공간 미빌드: $WAF_WS"
fi
wafbring() {
    _waf_role pi || return
    wafsource || return
    ros2 launch waffle waffle_bringup.launch.py "$@"
}
wafcamera() {
    _waf_role pi || return
    if [ ! -r "$WAF_CAMERA_WS/install/setup.bash" ] || [ ! -r "$WAF_CAMERA_WS/scripts/waffle_camera_manager.py" ]; then
        echo "[WAF] 카메라 작업 공간/매니저 없음: $WAF_CAMERA_WS"
        return 1
    fi
    source /opt/ros/jazzy/setup.bash || return
    source "$WAF_CAMERA_WS/install/setup.bash" || return
    wafnetwork
    python3 "$WAF_CAMERA_WS/scripts/waffle_camera_manager.py" "$@"
}
wafnav2() {
    _waf_role jetson || return
    wafsource || return
    local params="${WAF_NAV_PARAMS:-$WAF_WS/config/waffle_real_nav.yaml}" file
    for file in "$LOGITLE_MAP" "$LOGITLE_MASK" "$params"; do
        if [ ! -r "$file" ]; then echo "[WAF] 지도/주행 설정 파일 없음: $file"; return 1; fi
    done
    ros2 launch turtlebot3_navigation2 navigation2.launch.py use_sim_time:=false \
        map:="$LOGITLE_MAP" mask:="$LOGITLE_MASK" params_file:="$params" "$@"
}
wafreplace() {
    _waf_role jetson || return
    wafsource || return
    if [ ! -r "$WAF_WS/src/pallet_replace_server.py" ] || [ ! -x "$WAF_PYTHON" ]; then
        echo "[WAF] 액션 서버/Python 없음: $WAF_WS/src/pallet_replace_server.py / $WAF_PYTHON"
        return 1
    fi
    "$WAF_PYTHON" "$WAF_WS/src/pallet_replace_server.py" "$@"
}
wafgoal() {
    if [[ ! "${1:-}" =~ ^[1-9][0-9]*$ ]]; then echo '[WAF] 사용법: wafgoal <목적지 번호>'; return 1; fi
    local destination="$1"
    shift
    wafsource || return
    echo "[WAF] 실제 팔레트 교체 요청: destination=$destination"
    ros2 action send_goal /pallet_replace waffle_interfaces/action/PalletReplace "{destination: $destination}" --feedback "$@"
}
waf_service() {
    /usr/bin/python3 "$_LOGITLE_WAF_DIR/service.py" "$@"
}
# Jetson만 Domain 11 DDS와 FMS Zenoh를 연결. 내부 토픽 이름은 유지.
waf_zenoh() {
    _waf_role jetson || return
    if [ "${ROS_DOMAIN_ID:-}" != 11 ] || [ "${RMW_IMPLEMENTATION:-}" != rmw_cyclonedds_cpp ] || \
       [ "${ROS_AUTOMATIC_DISCOVERY_RANGE:-}" != SUBNET ] || [ "${ROS_LOCALHOST_ONLY:-0}" != 0 ]; then
        echo '[WAF] 먼저 wafnetwork 실행: Domain 11 / CycloneDDS / SUBNET 필요'
        return 1
    fi
    if ! command -v zenoh-bridge-ros2dds >/dev/null 2>&1; then
        echo '[WAF] Jetson에서 bash scripts/waffle/install.sh --role jetson 실행 필요'
        return 1
    fi
    local router_ip="${1:-${ZENOH_ROUTER_IP:-192.168.0.16}}"
    if [ "$#" -gt 0 ]; then shift; fi
    echo "[WAF] Jetson robot4 · DDS Domain 11 / SUBNET · Router tcp/${router_ip}:7447"
    zenoh-bridge-ros2dds -c "$_LOGITLE_WAF_DIR/bridge.json5" -d 11 -n /robot4 \
        --ros-automatic-discovery-range SUBNET -e "tcp/${router_ip}:7447" client "$@"
}
zenoh_start() {
    if [ "${1#/}" != robot4 ] || [ -z "${2:-}" ]; then
        echo '[WAF] 사용법: zenoh_start robot4 <FMS_IP> 또는 logizenoh <FMS_IP>'
        return 1
    fi
    shift
    waf_zenoh "$@"
}
alias sl='wafsource'
alias logibring='wafbring'
alias logicam='wafcamera'
alias loginav2='wafnav2'
