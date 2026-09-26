#!/usr/bin/env bash
set -e

# root 권한 확인
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] sudo 권한으로 실행해야 합니다: sudo bash $0"
  exit 1
fi

# 기본값 정의
DEFAULT_IFACE="wlan0"
DEFAULT_GATEWAY="192.168.0.1"
DEFAULT_DNS="8.8.8.8, 1.1.1.1"
NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"

# 옵션 플래그 파싱 (-s: SSID, -p: 비밀번호, -i: IP/서브넷, -g: 게이트웨이, -d: DNS)
while getopts "s:p:i:g:d:h" opt; do
  case $opt in
    s) SSID="$OPTARG" ;;
    p) PASSWORD="$OPTARG" ;;
    i) STATIC_IP="$OPTARG" ;;
    g) GATEWAY="$OPTARG" ;;
    d) DNS_SERVERS="$OPTARG" ;;
    h)
      echo "사용법: sudo $0 [-s SSID] [-p 비밀번호] [-i IP/서브넷] [-g 게이트웨이] [-d DNS]"
      echo "예시: sudo $0 -s 'MyWiFi' -p 'pass1234' -i '192.168.0.50/24'"
      exit 0
      ;;
    *)
      exit 1
      ;;
  esac
done

# 플래그로 입력되지 않은 항목은 대화형 입력 처리
if [ -z "$SSID" ]; then
  read -rp "Wi-Fi SSID 입력: " SSID
  while [ -z "$SSID" ]; do
    echo "SSID는 비어 있을 수 없습니다."
    read -rp "Wi-Fi SSID 입력: " SSID
  done
fi

if [ -z "$PASSWORD" ]; then
  read -rsp "Wi-Fi 비밀번호 입력 (화면에 표시되지 않음): " PASSWORD
  echo ""
  while [ -z "$PASSWORD" ]; do
    echo "비밀번호는 비어 있을 수 없습니다."
    read -rsp "Wi-Fi 비밀번호 입력: " PASSWORD
    echo ""
  done
fi

if [ -z "$STATIC_IP" ]; then
  read -rp "할당할 고정 IP/CIDR (예: 192.168.0.50/24): " STATIC_IP
  while [[ ! "$STATIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; do
    echo "[!] 형식 오류: IP/CIDR 형식(예: 192.168.0.50/24)으로 입력하세요."
    read -rp "할당할 고정 IP/CIDR: " STATIC_IP
  done
fi

if [ -z "$GATEWAY" ]; then
  read -rp "게이트웨이 IP [기본값: $DEFAULT_GATEWAY]: " GATEWAY
  GATEWAY="${GATEWAY:-$DEFAULT_GATEWAY}"
fi

if [ -z "$DNS_SERVERS" ]; then
  read -rp "DNS 서버 목록 [기본값: $DEFAULT_DNS]: " DNS_SERVERS
  DNS_SERVERS="${DNS_SERVERS:-$DEFAULT_DNS}"
fi

read -rp "네트워크 인터페이스 [기본값: $DEFAULT_IFACE]: " IFACE
IFACE="${IFACE:-$DEFAULT_IFACE}"

echo ""
echo "=== 설정 정보 확인 ==="
echo "인터페이스 : $IFACE"
echo "Wi-Fi SSID : $SSID"
echo "고정 IP    : $STATIC_IP"
echo "게이트웨이 : $GATEWAY"
echo "DNS 서버   : $DNS_SERVERS"
echo "======================="
read -rp "이 설정으로 Netplan을 갱신하시겠습니까? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "작업이 취소되었습니다."
  exit 0
fi

# 기존 Netplan 설정 백업
if [ -f "$NETPLAN_FILE" ]; then
  BACKUP_PATH="${NETPLAN_FILE}.bak_$(date +%Y%m%d%H%M%S)"
  echo "[+] 기존 Netplan 파일 백업: $BACKUP_PATH"
  cp "$NETPLAN_FILE" "$BACKUP_PATH"
fi

# Netplan 설정 작성
echo "[+] Netplan 설정 파일 생성 중 ($NETPLAN_FILE)..."
cat <<EOF > "$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  wifis:
    ${IFACE}:
      dhcp4: false
      addresses:
        - ${STATIC_IP}
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses: [${DNS_SERVERS}]
      access-points:
        "${SSID}":
          password: "${PASSWORD}"
EOF

# 파일 권한 설정 (600: Netplan 보안 권한 및 평문 비밀번호 보호)
chmod 600 "$NETPLAN_FILE"

# 설정 적용
echo "[+] 네트워크 설정 적용 중 (netplan apply)..."
netplan apply

echo "[✔] 설정 완료."
echo "적용 확인: ip addr show $IFACE"
