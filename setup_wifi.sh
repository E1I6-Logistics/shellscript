#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "[오류] 이 스크립트는 root 권한으로 실행해야 합니다. 'sudo $0'으로 실행해주세요."
  exit 1
fi

SSID="$1"
PASSWORD="$2"
STATIC_IP="$3"
GATEWAY="$4"

if [ -z "$SSID" ]; then
  read -rp "연결할 Wi-Fi SSID를 입력하세요: " SSID
fi

if [ -z "$PASSWORD" ]; then
  read -rsp "Wi-Fi 비밀번호를 입력하세요 (암호 없으면 Enter): " PASSWORD
  echo ""
fi

if [ -n "$STATIC_IP" ] && [ -n "$GATEWAY" ]; then
  SET_STATIC="y"
else
  read -rp "연결 후 고정 IP를 설정하시겠습니까? (y/n, 그냥 엔터치면 자동IP): " SET_STATIC
  if [[ "$SET_STATIC" =~ ^[Yy]$ ]]; then
    read -rp "할당할 IP (예: 192.168.0.101): " STATIC_IP
    read -rp "게이트웨이 (예: 192.168.0.1): " GATEWAY
  fi
fi

ORIGINAL_SSID=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2)

echo "=========================================="
echo "Wi-Fi 연결 시도 중..."
echo "타겟 SSID: $SSID"
[ -n "$ORIGINAL_SSID" ] && echo "현재 연결된 SSID: $ORIGINAL_SSID"
echo "=========================================="

rfkill unblock wifi 2>/dev/null
nmcli radio wifi on 2>/dev/null
nmcli device set wlan0 managed yes 2>/dev/null

# 기존 꼬인 프로필 및 인터페이스 IP 정리
nmcli connection delete id "$SSID" 2>/dev/null || true
ip addr flush dev wlan0 2>/dev/null || true

# 1단계: 공유기와 먼저 무선 결합 (성공했던 방식)
if [ -n "$PASSWORD" ]; then
  CONNECT_LOG=$(nmcli device wifi connect "$SSID" password "$PASSWORD" ifname wlan0 2>&1)
else
  CONNECT_LOG=$(nmcli device wifi connect "$SSID" ifname wlan0 2>&1)
fi
STATUS=$?

if [ $STATUS -eq 0 ]; then
  echo "[성공] '$SSID' 무선 결합 성공!"
  
  # 2단계: 고정 IP 요구 시 프로필 수정 후 재적용
  if [[ "$SET_STATIC" =~ ^[Yy]$ ]]; then
    echo "[설정] 고정 IP($STATIC_IP) 주입 중..."
    nmcli connection modify "$SSID" ipv4.addresses "$STATIC_IP/24" ipv4.gateway "$GATEWAY" ipv4.dns "8.8.8.8,8.8.4.4" ipv4.method manual
    nmcli connection up id "$SSID" >/dev/null 2>&1
  fi

  sleep 2
  IP_ADDR=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  echo "=========================================="
  echo "🎉 [최종 정보] 할당된 wlan0 IP: ${IP_ADDR:-확인 중...}"
  echo "=========================================="
else
  echo "[실패] 연결에 실패했습니다."
  echo "오류 세부사항: $CONNECT_LOG"

  if [ -n "$ORIGINAL_SSID" ] && [ "$ORIGINAL_SSID" != "$SSID" ]; then
    echo "[복구] 이전 Wi-Fi('$ORIGINAL_SSID')로 재연결을 시도합니다..."
    nmcli connection up id "$ORIGINAL_SSID" >/dev/null 2>&1
  fi
  exit 1
fi

