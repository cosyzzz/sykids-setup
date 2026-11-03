#!/usr/bin/env bash
# ============================================================================
# Cosy Classroom System — Linux Workstation Quick Bootstrap (Ubuntu/Debian)
# ============================================================================
set -euo pipefail

# Auto-elevate via sudo if executed as non-root
if [ "$(id -u)" -ne 0 ]; then
    echo "[Cosy] Can quyen root de cai dat dich vu he thong. Dang chuyen sang sudo..."
    exec sudo -E bash "$0" "$@"
fi

SERVER_URL="${SYKIDS_SERVER:-}"
TICKET="${SYKIDS_TICKET:-}"
VERBOSE=0

print_usage() {
    cat <<EOF
Cosy Classroom System — Linux Installer

Cu phap:
  sudo bash setup-xubuntu.sh [TUY_CHON]

Tuy chon:
  -s, --server <URL>    Dia chi may chu Cosy Classroom (Vi du: https://sykids.dpdns.org)
  -t, --ticket <TICKET> Ma ve ghi danh lop hoc (khong bat buoc)
  -v, --verbose         Hien thi chi tiet qua trinh cai dat
  -h, --help            Hien thi huong dan nay
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--server)
            SERVER_URL="$2"
            shift 2
            ;;
        -t|--ticket)
            TICKET="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            if [[ "$1" =~ ^https?:// ]]; then
                SERVER_URL="$1"
            elif [ -z "$TICKET" ]; then
                TICKET="$1"
            fi
            shift
            ;;
    esac
done

echo "============================================================================"
echo "  Cosy Classroom System — Linux Workstation Setup (Ubuntu / Debian)        "
echo "============================================================================"

# Tao thu muc tam an toan
TMP_DIR="$(mktemp -d -t cosy-setup-XXXXXX)"
chmod 700 "$TMP_DIR"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# [1/4] (25%) Resolve SERVER_URL
echo "[Cosy] [1/4] (25%) Dang xac dinh may chu Cosy Classroom..."
if [ -z "$SERVER_URL" ]; then
    BEACON_FILE="$TMP_DIR/beacon.txt"
    if curl --retry 2 --connect-timeout 5 --max-time 10 -fsSL "https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/beacon.txt" -o "$BEACON_FILE" 2>/dev/null; then
        if [ -s "$BEACON_FILE" ]; then
            BEACON_LINE="$(head -n 1 "$BEACON_FILE")"
            BEACON_HEADER="$(echo "$BEACON_LINE" | cut -d'|' -f1)"
            BEACON_WS="$(echo "$BEACON_LINE" | cut -d'|' -f2)"
            if [ "$BEACON_HEADER" = "SYKIDS-BEACON-V2" ] && [ -n "$BEACON_WS" ]; then
                CANDIDATE="${BEACON_WS/wss:\/\//https:\/\/}"
                CANDIDATE="${CANDIDATE/ws:\/\//http:\/\/}"
                CANDIDATE="${CANDIDATE%/ws}"
                
                HTTP_CODE="$(curl -sS -I -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 8 "$CANDIDATE/cosy/linux.sh" 2>/dev/null || true)"
                if [ "$HTTP_CODE" = "200" ]; then
                    SERVER_URL="$CANDIDATE"
                fi
            fi
        fi
    fi
fi

if [ -z "$SERVER_URL" ]; then
    SERVER_URL="https://sykids.dpdns.org"
fi
echo "[Cosy] [1/4] May chu duoc chon: $SERVER_URL"

# [2/4] (50%) Download upstream linux installer script
echo "[Cosy] [2/4] (50%) Dang tai kich ban cai dat he thong tu may chu..."
UPSTREAM_SCRIPT="$TMP_DIR/cosy-linux.sh"
AUTH_QUERY=""
if [ -n "$TICKET" ]; then
    AUTH_QUERY="?t=$(echo -n "$TICKET" | tr -d '\r\n')"
fi

if ! curl --retry 3 --retry-all-errors -fsSL --connect-timeout 15 --max-time 60 "${SERVER_URL}/cosy/linux.sh${AUTH_QUERY}" -o "$UPSTREAM_SCRIPT"; then
    echo "[!] Loi: Khong the tai kich ban /cosy/linux.sh tu $SERVER_URL"
    exit 1
fi
chmod 700 "$UPSTREAM_SCRIPT"

# [3/4] (75%) Execute upstream installer
echo "[Cosy] [3/4] (75%) Dang thiet lap cac dich vu giam sat lop hoc..."
if [ "$VERBOSE" -eq 1 ]; then
    bash "$UPSTREAM_SCRIPT"
else
    bash "$UPSTREAM_SCRIPT" >/dev/null 2>&1 || bash "$UPSTREAM_SCRIPT"
fi

# [4/4] (100%) Verify systemd units
echo "[Cosy] [4/4] (100%) Kiem tra trang thai dich vu he thong..."
SVC_ACTIVE=0
if systemctl is-active --quiet cpsv.service 2>/dev/null; then
    echo "  [OK] cpsv.service (Cosy Protection Core) dang hoat dong."
    SVC_ACTIVE=1
fi
if systemctl is-active --quiet cpwg.service 2>/dev/null; then
    echo "  [OK] cpwg.service (Cosy Watchdog Service) dang hoat dong."
    SVC_ACTIVE=1
fi

if [ "$SVC_ACTIVE" -eq 1 ]; then
    echo "[Cosy] [100%] Da cai dat thanh cong dich vu he thong (cpsv.service / cpwg.service)!"
else
    echo "[Cosy] Hoan tat quy trinh cai dat. Kiem tra bang: sudo systemctl status cpsv.service cpwg.service"
fi
exit 0
