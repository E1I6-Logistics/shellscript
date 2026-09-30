#!/usr/bin/env bash

# 환경 변수 설정
export LOGITLE_MAP="$HOME/logitle_ws/src/turtlebot3/turtlebot3_navigation2/map/logitle_map_fin.yaml"
export LOGITLE_MASK="$HOME/logitle_ws/src/turtlebot3/turtlebot3_navigation2/map/logitle_map_fin_keepout.yaml"

# 워크스페이스 소싱 alias (실행 성공 시 메시지 출력)
alias sl='source ~/logitle_ws/install/setup.bash && echo "[OK] logitle_ws sourced"'
alias st='source ~/turtlebot3_ws/install/setup.bash && echo "[OK] turtlebot3_ws sourced"'

# 실행 명령 alias
alias loginav2='ros2 launch turtlebot3_navigation2 navigation2_robot.launch.py map:="${LOGITLE_MAP}" mask:="${LOGITLE_MASK}"'
alias turtlebring='ros2 launch turtlebot3_bringup robot.launch.py'
alias logidock='ros2 run logitle_docking precision_docking_ICP_align_server_V2.py'
alias logibring='ros2 launch logitle_bringup logitle_robot.launch.py'
alias logizenho='ros2 launch zenoh_pkg zenoh.launch.py robot_id:=robot3 router_ip:=192.168.0.100'

source /opt/ros/jazzy/setup.bash

export TURTLEBOT3_MODEL=burger
export OPENCR_MODEL=burger
export OPENCR_PORT=/dev/ttyACM0
alias roskill='pkill -9 -f ros2; pkill -9 -f zenoh; pkill -9 -f robot_agent.py; echo "✅ ROS 2 및 통신 프로세스 강제 종료 완료"'

# ============================================================
# Default mode: NORMAL
# Robot1=30 / Robot2=31 / Robot3=32
# FastDDS + SUBNET
# ============================================================
case "$(hostname)" in
    turtlebot1) export ROS_DOMAIN_ID=30 ;;
    turtlebot2) export ROS_DOMAIN_ID=31 ;;
    turtlebot3) export ROS_DOMAIN_ID=32 ;;
    *)          export ROS_DOMAIN_ID=30 ;;
esac

export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY

# ============================================================
# LOCAL / ZENOH MODE
# Domain 0 + CycloneDDS + LOCALHOST
# Usage: ros_local
# ============================================================
ros_local() {
    export ROS_DOMAIN_ID=0
    export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
    export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
    unset ROS_LOCALHOST_ONLY

    ros2 daemon stop >/dev/null 2>&1 || true
    ros2 daemon start >/dev/null 2>&1 || true

    echo "================================="
    echo " 🔒 ROS2 LOCAL / ZENOH MODE"
    echo "================================="
    echo "HOSTNAME  : $(hostname)"
    echo "DOMAIN    : $ROS_DOMAIN_ID"
    echo "RMW       : $RMW_IMPLEMENTATION"
    echo "DISCOVERY : $ROS_AUTOMATIC_DISCOVERY_RANGE"
    echo "================================="
}

# ============================================================
# NORMAL DDS MODE
# Robot1=30 / Robot2=31 / Robot3=32
# FastDDS + SUBNET
# Usage: ros_normal
# ============================================================
ros_normal() {
    case "$(hostname)" in
        turtlebot1) export ROS_DOMAIN_ID=30 ;;
        turtlebot2) export ROS_DOMAIN_ID=31 ;;
        turtlebot3) export ROS_DOMAIN_ID=32 ;;
        *)
            echo "❌ Unknown hostname: $(hostname)"
            return 1
            ;;
    esac

    export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
    export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
    unset ROS_LOCALHOST_ONLY

    ros2 daemon stop >/dev/null 2>&1 || true
    ros2 daemon start >/dev/null 2>&1 || true

    echo "================================="
    echo " 🌐 ROS2 NORMAL MODE"
    echo "================================="
    echo "HOSTNAME  : $(hostname)"
    echo "DOMAIN    : $ROS_DOMAIN_ID"
    echo "RMW       : $RMW_IMPLEMENTATION"
    echo "DISCOVERY : $ROS_AUTOMATIC_DISCOVERY_RANGE"
    echo "================================="
}

# ============================================================
# Start Zenoh ROS2DDS Bridge
#
# 사용:
#   zenoh_start <ROBOT_NS> <ROUTER_IP>
#
# 예:
#   zenoh_start robot1 10.10.141.xx
#   zenoh_start robot2 10.10.141.xx
#   zenoh_start robot3 10.10.141.xx
# ============================================================

zenoh_start() {

    if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
        echo "❌ ROBOT_NS와 Zenoh Router IP를 입력하세요."
        echo ""
        echo "사용법:"
        echo "  zenoh_start <ROBOT_NS> <ROUTER_IP>"
        echo ""
        echo "예시:"
        echo "  zenoh_start robot1 10.10.141.xx"
        echo "  zenoh_start robot2 10.10.141.xx"
        echo "  zenoh_start robot3 10.10.141.xx"
        return 1
    fi

    local ROBOT_NS="$1"
    local ROUTER_IP="$2"

    # / 없이 입력해도 자동으로 붙임
    ROBOT_NS="/${ROBOT_NS#/}"

    # LOCAL / Zenoh 환경 확인
    if [ "${ROS_DOMAIN_ID:-}" != "0" ] || \
       [ "${RMW_IMPLEMENTATION:-}" != "rmw_cyclonedds_cpp" ] || \
       [ "${ROS_AUTOMATIC_DISCOVERY_RANGE:-}" != "LOCALHOST" ]; then

        echo "❌ LOCAL / Zenoh 환경이 아닙니다."
        echo "먼저 'ros_local'을 실행하세요."
        echo ""
        echo "현재 설정:"
        echo "DOMAIN    : ${ROS_DOMAIN_ID:-NOT SET}"
        echo "RMW       : ${RMW_IMPLEMENTATION:-NOT SET}"
        echo "DISCOVERY : ${ROS_AUTOMATIC_DISCOVERY_RANGE:-NOT SET}"
        return 1
    fi

    echo "================================="
    echo " 🚀 ZENOH BRIDGE START"
    echo "================================="
    echo "ROBOT NS  : $ROBOT_NS"
    echo "DOMAIN    : $ROS_DOMAIN_ID"
    echo "RMW       : $RMW_IMPLEMENTATION"
    echo "DISCOVERY : $ROS_AUTOMATIC_DISCOVERY_RANGE"
    echo "ROUTER    : ${ROUTER_IP}:7447"
    echo "================================="

    zenoh-bridge-ros2dds \
        -d "$ROS_DOMAIN_ID" \
        -n "$ROBOT_NS" \
        --ros-automatic-discovery-range "$ROS_AUTOMATIC_DISCOVERY_RANGE" \
        -e "tcp/${ROUTER_IP}:7447" \
        client
}

# ============================================================
# Robot network info
# Usage: robot_info
# ============================================================
robot_info() {
    echo "================================="
    echo " 🤖 ROBOT NETWORK INFO"
    echo "================================="
    echo "HOSTNAME        : $(hostname)"
    echo "IP ADDRESS      : $(hostname -I | awk '{print $1}')"
    echo "ROS_DISTRO      : ${ROS_DISTRO:-NOT SET}"
    echo "ROS_DOMAIN_ID   : ${ROS_DOMAIN_ID:-0}"
    echo "RMW             : ${RMW_IMPLEMENTATION:-DEFAULT}"
    echo "DISCOVERY_RANGE : ${ROS_AUTOMATIC_DISCOVERY_RANGE:-DEFAULT}"
    echo "LOCALHOST_ONLY  : ${ROS_LOCALHOST_ONLY:-NOT SET}"
    echo "---------------------------------"

    if pgrep -f "zenoh-bridge-ros2dds" >/dev/null; then
        echo "ZENOH BRIDGE    : RUNNING"
    else
        echo "ZENOH BRIDGE    : STOPPED"
    fi

    if pgrep -f "robot_agent" >/dev/null; then
        echo "ROBOT AGENT     : RUNNING"
    else
        echo "ROBOT AGENT     : STOPPED"
    fi
    echo "================================="
}
