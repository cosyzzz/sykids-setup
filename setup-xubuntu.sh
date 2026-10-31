#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_URL="${SYKIDS_SERVER:-https://sykids.tail983a96.ts.net}"
TICKET="${SYKIDS_TICKET:-}"
VERBOSE=0
ORIG_ARGS=("$@")

usage() {
  cat <<'EOF'
Cách dùng (SYKids Xubuntu/Linux Setup):
  curl -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-xubuntu.sh | sudo bash -s -- <MA_VE_1_LAN>

Tùy chọn:
  -t, --ticket <MA_VE>   Mã vé cài đặt 1 lần lấy từ Dashboard SYKids
  -s, --server <URL>     Địa chỉ máy chủ SYKids (mặc định: https://sykids.tail983a96.ts.net)
  -v, --verbose          Hiển thị chi tiết nhật ký cài đặt
  -h, --help             Hiển thị hướng dẫn này
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--ticket)
      if [ $# -lt 2 ]; then
        printf '\033[31m[SYKids] Thiếu giá trị cho tùy chọn %s.\033[0m\n' "$1" >&2
        usage >&2
        exit 1
      fi
      TICKET="$2"
      shift 2
      ;;
    --ticket=*|-t=*)
      TICKET="${1#*=}"
      shift
      ;;
    -s|--server)
      if [ $# -lt 2 ]; then
        printf '\033[31m[SYKids] Thiếu giá trị cho tùy chọn %s.\033[0m\n' "$1" >&2
        usage >&2
        exit 1
      fi
      SERVER_URL="$2"
      shift 2
      ;;
    --server=*|-s=*)
      SERVER_URL="${1#*=}"
      shift
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      if [ $# -gt 0 ] && [ -z "$TICKET" ]; then
        TICKET="$1"
      fi
      break
      ;;
    -*)
      printf '\033[31m[SYKids] Tùy chọn không hợp lệ: %s\033[0m\n' "$1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ -z "$TICKET" ]; then
        TICKET="$1"
      fi
      shift
      ;;
  esac
done

if [ "${#ORIG_ARGS[@]}" -gt 0 ]; then
  set -- "${ORIG_ARGS[@]}"
else
  set --
fi

while [[ "$SERVER_URL" == */ ]]; do
  SERVER_URL="${SERVER_URL%/}"
done

if [[ ! "$SERVER_URL" =~ ^https?://[^[:space:]/][^[:space:]]*$ ]]; then
  printf '\033[31m[SYKids] Địa chỉ máy chủ không hợp lệ: %s (phải bắt đầu bằng https:// hoặc http://).\033[0m\n' "$SERVER_URL" >&2
  exit 1
fi

if [ -z "$TICKET" ]; then
  printf '\033[31m[SYKids] Thiếu mã vé cài đặt 1 lần.\033[0m\n' >&2
  usage >&2
  exit 1
fi

if ! ( LC_ALL=C; [[ "$TICKET" =~ ^[A-Za-z0-9._~+/-]+=*$ ]] ); then
  printf '\033[31m[SYKids] Mã vé cài đặt không hợp lệ.\033[0m\n' >&2
  usage >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ] && [ "${CP_NO_SUDO_REEXEC:-0}" != "1" ]; then
    CP_NO_SUDO_REEXEC=1 exec sudo -E bash "${BASH_SOURCE[0]}" "$@"
  else
    printf '\033[31m[SYKids] Vui lòng chạy với sudo: curl -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-xubuntu.sh | sudo bash -s -- <MA_VE_1_LAN>\033[0m\n' >&2
    exit 1
  fi
fi

show_step() {
  local pct="${1:-0}"
  if [ "$pct" -lt 0 ]; then pct=0; fi
  if [ "$pct" -gt 100 ]; then pct=100; fi
  local filled=$(( pct * 20 / 100 ))
  local hashes="####################"
  local dashes="--------------------"
  local bar="${hashes:0:filled}${dashes:0:20-filled}"
  printf '\r\033[36m[SYKids] Đang thiết lập dịch vụ... [%s] %3d%%\033[0m   ' "$bar" "$pct"
}

show_step 0

TMP_DIR="$(mktemp -d /tmp/sykids-setup.XXXXXX)"
chmod 700 "$TMP_DIR"
INST_PID=""

cleanup() {
  if [ -n "$INST_PID" ] && kill -0 "$INST_PID" 2>/dev/null; then
    kill "$INST_PID" 2>/dev/null || true
  fi
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

if ! command -v curl >/dev/null 2>&1; then
  if ! ( DEBIAN_FRONTEND=noninteractive apt-get update -y -qq >/dev/null 2>&1 && \
         DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends curl ca-certificates >/dev/null 2>&1 ); then
    printf '\n\033[31m[SYKids] Không thể cài đặt gói phụ thuộc (curl, ca-certificates).\033[0m\n' >&2
    exit 1
  fi
fi

show_step 15

show_step 30
HTTP_CODE="$(curl -sSL -w '%{http_code}' --connect-timeout 15 --max-time 60 --get --data-urlencode "t=${TICKET}" "${SERVER_URL}/install-xubuntu.sh" -o "$TMP_DIR/install.sh" || true)"
HTTP_CODE="${HTTP_CODE:-000}"

case "$HTTP_CODE" in
  200)
    if [ ! -s "$TMP_DIR/install.sh" ]; then
      printf '\n\033[31m[SYKids] Không thể tải trình cài đặt từ máy chủ (HTTP %s).\033[0m\n' "$HTTP_CODE" >&2
      exit 1
    fi
    ;;
  401|403)
    printf '\n\033[31m[SYKids] Vé cài đặt không hợp lệ hoặc đã được sử dụng (mỗi vé chỉ dùng 1 lần). Hãy lấy vé mới trên Dashboard.\033[0m\n' >&2
    exit 1
    ;;
  410)
    printf '\n\033[31m[SYKids] Vé cài đặt đã hết hạn. Hãy lấy vé mới trên Dashboard.\033[0m\n' >&2
    exit 1
    ;;
  *)
    printf '\n\033[31m[SYKids] Không thể tải trình cài đặt từ máy chủ (HTTP %s).\033[0m\n' "$HTTP_CODE" >&2
    exit 1
    ;;
esac

show_step 50
chmod 700 "$TMP_DIR/install.sh"

if [ "$VERBOSE" -eq 1 ]; then
  printf '\n'
  RC=0
  bash "$TMP_DIR/install.sh" --verbose </dev/null || RC=$?
  if [ "$RC" -ne 0 ]; then
    printf '\033[31m[SYKids] Cài đặt dịch vụ thất bại (mã lỗi %d).\033[0m\n' "$RC" >&2
    exit "$RC"
  fi
  show_step 100
else
  bash "$TMP_DIR/install.sh" </dev/null >"$TMP_DIR/install.log" 2>&1 &
  INST_PID=$!
  PCT=55
  while kill -0 "$INST_PID" 2>/dev/null; do
    show_step "$PCT"
    sleep 0.4
    if [ "$PCT" -lt 92 ]; then
      PCT=$(( PCT + 1 ))
    fi
  done

  RC=0
  wait "$INST_PID" || RC=$?
  INST_PID=""
  if [ "$RC" -ne 0 ]; then
    printf '\n\033[31m[SYKids] Cài đặt dịch vụ thất bại (mã lỗi %d). Nhật ký chi tiết:\033[0m\n' "$RC" >&2
    tail -n 20 "$TMP_DIR/install.log" >&2 || true
    exit "$RC"
  fi
fi

show_step 100
printf '\n\033[32m[SYKids] Đã cài đặt xong dịch vụ — Thiết bị đã sẵn sàng kết nối!\033[0m\n'
