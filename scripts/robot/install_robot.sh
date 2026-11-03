#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f /opt/ros/jazzy/setup.bash ]] || {
    echo "ERROR: ROS 2 Jazzy not found."
    exit 1
}


add_zenoh_repo() {
    sudo install -d -m 0755 /etc/apt/keyrings

    curl -L https://download.eclipse.org/zenoh/debian-repo/zenoh-public-key \
      | sudo gpg --dearmor --yes \
        --output /etc/apt/keyrings/zenoh-public-key.gpg

    echo "deb [signed-by=/etc/apt/keyrings/zenoh-public-key.gpg] https://download.eclipse.org/zenoh/debian-repo/ /" \
      | sudo tee /etc/apt/sources.list.d/zenoh.list >/dev/null

    sudo apt update
}


echo "[1/5] Install base/RMW packages"
sudo apt update
mapfile -t PKGS < <(grep -Ev '^[[:space:]]*(#|$)' "$SCRIPT_DIR/requirements.txt")
sudo apt install -y "${PKGS[@]}"

echo "[2/5] Add Eclipse Zenoh repository"
add_zenoh_repo

echo "[3/5] Install zenoh-bridge-ros2dds 1.9.0"
sudo apt install -y zenoh-bridge-ros2dds=1.9.0 --allow-downgrades

echo "[4/5] Hold Zenoh bridge"
sudo apt-mark hold zenoh-bridge-ros2dds

echo "[5/5] Verify"
set +u
source /opt/ros/jazzy/setup.bash
set -u
ros2 pkg prefix rmw_cyclonedds_cpp
ros2 pkg prefix rmw_fastrtps_cpp
zenoh-bridge-ros2dds --version

echo
echo "Robot installation complete."
bash "$SCRIPT_DIR/configure_shell.sh"
echo "Next: source ~/.bashrc (waffle -> robot4, Domain 11 / Zenoh Domain 0)"
