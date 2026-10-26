#!/bin/bash

echo "🔍 TurtleBot 와이파이(wlan0) 고정 IP 설정을 시작합니다..."
echo "----------------------------------------"

# 사용자로부터 IP 정보 입력받기
read -p "할당할 고정 IP를 입력하세요 (예: 10.10.141.221): " STATIC_IP
read -p "게이트웨이를 입력하세요 (예: 10.10.141.254): " GATEWAY

if [ -z "$STATIC_IP" ] || [ -z "$GATEWAY" ]; then
    echo "❌ IP 또는 게이트웨이가 입력되지 않아 설정을 취소합니다."
    exit 1
fi

FILE_PATH="/etc/netplan/50-cloud-init.yaml"

# 만약을 대비해 기존 설정 파일 백업
if [ -f "$FILE_PATH" ]; then
    sudo cp "$FILE_PATH" "${FILE_PATH}.bak"
    echo "✅ 기존 설정 파일이 안전하게 백업되었습니다. (${FILE_PATH}.bak)"
fi

echo "⚙️  고정 IP($STATIC_IP) 설정을 덮어쓰고 적용합니다..."

# 새로운 Netplan 설정 파일 생성 (기존 정보 포함)
sudo bash -c "cat > $FILE_PATH" <<EOF
network:
  version: 2
  ethernets:
    eth0:
      optional: true
      dhcp4: true
      dhcp6: true
  wifis:
    wlan0:
      optional: true
      dhcp4: no
      addresses:
        - $STATIC_IP/24
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      regulatory-domain: "KR"
      access-points:
        "robotA":
          auth:
            key-management: "psk"
            password: "9b1c5c65b1bdf7049eef2a264cf882162f456845499479c69a5bcf504fa1a318"
EOF

# 파일 권한 설정 (보안 경고 방지)
sudo chmod 600 $FILE_PATH

# Netplan 설정 즉시 적용
sudo netplan apply

echo "----------------------------------------"
echo "🎉 설정이 완료되었습니다! 현재 할당된 wlan0 IP:"
ip -4 addr show wlan0
