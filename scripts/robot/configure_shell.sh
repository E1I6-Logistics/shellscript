#!/usr/bin/env bash
# 환경 등록만 수행한다. APT 설치·ROS/모터 실행·네트워크 설정 변경은 하지 않는다.
set -euo pipefail
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$SCRIPT_ROOT/scripts/robot/configure_shell.py" --source "$SCRIPT_ROOT/logitlebash.sh" "$@"
