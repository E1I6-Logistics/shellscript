#!/usr/bin/env bash

# Common ROS2 Jazzy / TurtleBot3 Burger environment for turtlebot1~3.
export LOGITLE_MAP="$HOME/logitle_ws/src/turtlebot3/turtlebot3_navigation2/map/logitle_map_fin.yaml"
export LOGITLE_MASK="$HOME/logitle_ws/src/turtlebot3/turtlebot3_navigation2/map/logitle_map_fin_keepout.yaml"

alias sl='source ~/logitle_ws/install/setup.bash && echo "[OK] logitle_ws sourced"'
alias st='source ~/turtlebot3_ws/install/setup.bash && echo "[OK] turtlebot3_ws sourced"'
alias loginav2='ros2 launch turtlebot3_navigation2 navigation2_robot.launch.py map:="${LOGITLE_MAP}" mask:="${LOGITLE_MASK}"'
alias turtlebring='ros2 launch turtlebot3_bringup robot.launch.py'
alias logidock='ros2 run logitle_docking precision_docking_ICP_align_server_V2.py'
alias logibring='ros2 launch logitle_bringup logitle_robot.launch.py'

case "$(hostname)" in
    turtlebot1) export ROBOT_ID=robot1; export ROBOT_DOMAIN_ID=30 ;;
    turtlebot2) export ROBOT_ID=robot2; export ROBOT_DOMAIN_ID=31 ;;
    turtlebot3) export ROBOT_ID=robot3; export ROBOT_DOMAIN_ID=32 ;;
    *) export ROBOT_ID=''; export ROBOT_DOMAIN_ID=30 ;;
esac

# Preserve original logizenoh command and router IP; only robot_id is dynamic.
logizenoh() {
    if [ -z "$ROBOT_ID" ]; then
        echo "[ERROR] Unknown hostname: $(hostname)"
        return 1
    fi
    ros2 launch zenoh_pkg zenoh.launch.py robot_id:="$ROBOT_ID" router_ip:=192.168.0.16 "$@"
}

logicam() {
    source /opt/ros/jazzy/setup.bash
    source ~/logitle_ws/install/setup.bash
    source ~/camera_ros_ws/install/setup.bash
    export LD_LIBRARY_PATH="/usr/local/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH:-}"
    ros2 launch turtlebot3_bringup camera.launch.py "$@"
}

source /opt/ros/jazzy/setup.bash
export TURTLEBOT3_MODEL=burger
export OPENCR_MODEL=burger
export OPENCR_PORT=/dev/ttyACM0

# DANGEROUS: Terminates ROS2, bridge and robot processes on this host.
roskill() {
    local patterns=(
        'ros2 launch' 'ros2 run' 'component_container'
        'zenoh-bridge-ros2dds' 'zenoh_bridge_node' 'zenoh'
        'robot_agent.py' 'controller_server' 'planner_server' 'bt_navigator'
        'waypoint_follower' 'lifecycle_manager' 'map_server' 'amcl'
        'precision_dock' 'ekf_node' 'ld08_driver' 'turtlebot3_ros'
        'robot_state_publisher' 'logitle_align_and_correct_action_server'
        'aruco_pose_corrector' 'aruco_tf_listener'
        'align_and_correct_image_listener' 'logitle_pose_publisher'
        'nav2'
    )
    local p
    echo '[roskill] Sending SIGTERM to ROS2-related processes...'
    for p in "${patterns[@]}"; do
        pkill -TERM -f -- "$p" 2>/dev/null || true
    done
    sleep 2
    echo '[roskill] Sending SIGKILL to remaining ROS2-related processes...'
    for p in "${patterns[@]}"; do
        pkill -KILL -f -- "$p" 2>/dev/null || true
    done
    ros2 daemon stop >/dev/null 2>&1 || true
    echo '[roskill] Complete'
}

case "$(hostname)" in
    turtlebot1) export ROS_DOMAIN_ID=30 ;;
    turtlebot2) export ROS_DOMAIN_ID=31 ;;
    turtlebot3) export ROS_DOMAIN_ID=32 ;;
    *) export ROS_DOMAIN_ID=30 ;;
esac
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY

ros_local() {
    export ROS_DOMAIN_ID=0
    export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
    export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
    unset ROS_LOCALHOST_ONLY
    ros2 daemon stop >/dev/null 2>&1 || true
    ros2 daemon start >/dev/null 2>&1 || true
    echo '================================='
    echo ' 🔒 ROS2 LOCAL / ZENOH MODE'
    echo '================================='
    echo "HOSTNAME  : $(hostname)"
    echo "DOMAIN    : $ROS_DOMAIN_ID"
    echo "RMW       : $RMW_IMPLEMENTATION"
    echo "DISCOVERY : $ROS_AUTOMATIC_DISCOVERY_RANGE"
    echo '================================='
}

ros_normal() {
    case "$(hostname)" in
        turtlebot1) export ROS_DOMAIN_ID=30 ;;
        turtlebot2) export ROS_DOMAIN_ID=31 ;;
        turtlebot3) export ROS_DOMAIN_ID=32 ;;
        *) echo "❌ Unknown hostname: $(hostname)"; return 1 ;;
    esac
    export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
    export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
    unset ROS_LOCALHOST_ONLY
    ros2 daemon stop >/dev/null 2>&1 || true
    ros2 daemon start >/dev/null 2>&1 || true
    echo '================================='
    echo ' 🌐 ROS2 NORMAL MODE'
    echo '================================='
    echo "HOSTNAME  : $(hostname)"
    echo "DOMAIN    : $ROS_DOMAIN_ID"
    echo "RMW       : $RMW_IMPLEMENTATION"
    echo "DISCOVERY : $ROS_AUTOMATIC_DISCOVERY_RANGE"
    echo '================================='
}

zenoh_start() {
    if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
        echo '❌ ROBOT_NS와 Zenoh Router IP를 입력하세요.'
        echo '사용법: zenoh_start <ROBOT_NS> <ROUTER_IP>'
        return 1
    fi
    local ROBOT_NS="/${1#/}"
    local ROUTER_IP="$2"
    if [ "${ROS_DOMAIN_ID:-}" != 0 ] || \
       [ "${RMW_IMPLEMENTATION:-}" != rmw_cyclonedds_cpp ] || \
       [ "${ROS_AUTOMATIC_DISCOVERY_RANGE:-}" != LOCALHOST ]; then
        echo '❌ LOCAL / Zenoh 환경이 아닙니다. 먼저 ros_local을 실행하세요.'
        printf 'DOMAIN: %s\nRMW: %s\nDISCOVERY: %s\n' \
            "${ROS_DOMAIN_ID:-NOT SET}" "${RMW_IMPLEMENTATION:-NOT SET}" \
            "${ROS_AUTOMATIC_DISCOVERY_RANGE:-NOT SET}"
        return 1
    fi
    echo '================================='
    echo ' 🚀 ZENOH BRIDGE START'
    echo '================================='
    echo "ROBOT NS  : $ROBOT_NS"
    echo "DOMAIN    : $ROS_DOMAIN_ID"
    echo "RMW       : $RMW_IMPLEMENTATION"
    echo "DISCOVERY : $ROS_AUTOMATIC_DISCOVERY_RANGE"
    echo "ROUTER    : ${ROUTER_IP}:7447"
    echo '================================='
    zenoh-bridge-ros2dds \
        -d "$ROS_DOMAIN_ID" \
        -n "$ROBOT_NS" \
        --ros-automatic-discovery-range "$ROS_AUTOMATIC_DISCOVERY_RANGE" \
        -e "tcp/${ROUTER_IP}:7447" \
        client
}

robot_info() {
    echo '================================='
    echo ' 🤖 ROBOT NETWORK INFO'
    echo '================================='
    echo "HOSTNAME        : $(hostname)"
    echo "IP ADDRESS      : $(hostname -I | awk '{print $1}')"
    echo "ROS_DISTRO      : ${ROS_DISTRO:-NOT SET}"
    echo "ROS_DOMAIN_ID   : ${ROS_DOMAIN_ID:-0}"
    echo "RMW             : ${RMW_IMPLEMENTATION:-DEFAULT}"
    echo "DISCOVERY_RANGE : ${ROS_AUTOMATIC_DISCOVERY_RANGE:-DEFAULT}"
    echo "LOCALHOST_ONLY  : ${ROS_LOCALHOST_ONLY:-NOT SET}"
    echo '---------------------------------'
    if pgrep -f '[z]enoh-bridge-ros2dds' >/dev/null; then
        echo 'ZENOH BRIDGE    : RUNNING'
    else
        echo 'ZENOH BRIDGE    : STOPPED'
    fi
    if pgrep -f '[r]obot_agent' >/dev/null; then
        echo 'ROBOT AGENT     : RUNNING'
    else
        echo 'ROBOT AGENT     : STOPPED'
    fi
    echo '================================='
}
