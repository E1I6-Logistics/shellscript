#!/usr/bin/env bash
set -e
export WAF_ROLE="${1:?WAF 역할 필요}"
component="${2:?실행 항목 필요}"
case "$WAF_ROLE:$component" in
    pi:bringup|pi:camera|jetson:nav2|jetson:pallet|jetson:zenoh) ;;
    *) echo '[WAF] 잘못된 서비스 역할/실행 항목' >&2; exit 1 ;;
esac
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_ROOT/logitlebash.sh"
case "$component" in
    bringup) wafbring ;;
    camera) wafcamera ;;
    nav2) wafnav2 ;;
    pallet) wafreplace ;;
    zenoh) waf_zenoh ;;
esac
