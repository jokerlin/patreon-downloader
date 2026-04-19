#!/bin/bash
# Patreon 视频下载脚本
# 依赖: yt-dlp, curl_cffi (pip install curl_cffi)
#
# 用法:
#   单个视频:  ./download-patreon.sh -o videos/2026-04-19 <url>
#   批量下载:  ./download-patreon.sh -f urls/2026-04-19.txt -o videos/2026-04-19
#   指定密码:  ./download-patreon.sh -p mypassword -o videos/2026-04-19 <url>
#
# 密码优先级: -p 参数 > .patreon-password 文件 > 无密码(走 SproutVideo 直链)
#
# 原理:
#   1. --impersonate chrome 模拟 Chrome TLS 指纹绕过 Cloudflare
#   2. 若有密码, 先尝试 --video-password 直接下载
#   3. 若无密码或密码失败, 从 API embed 提取 SproutVideo 直链 (含 token, 免密码)
#   4. 以 URL path 命名文件

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="."
URLS_FILE=""
PASSWORD=""
URLS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) OUTPUT_DIR="$2"; shift 2 ;;
    -f) URLS_FILE="$2"; shift 2 ;;
    -p) PASSWORD="$2"; shift 2 ;;
    *)  URLS+=("$1"); shift ;;
  esac
done

# 从密码文件读取 (脚本同目录下 .patreon-password)
if [[ -z "$PASSWORD" && -f "${SCRIPT_DIR}/.patreon-password" ]]; then
  PASSWORD=$(head -1 "${SCRIPT_DIR}/.patreon-password" | xargs)
fi

if [[ -n "$URLS_FILE" ]]; then
  while IFS= read -r line; do
    line=$(echo "$line" | sed 's/^[[:space:]]*[0-9]*[→ ]*//' | xargs)
    [[ "$line" == https://* ]] && URLS+=("$line")
  done < "$URLS_FILE"
fi

[[ ${#URLS[@]} -eq 0 ]] && { echo "用法: $0 [-o 输出目录] [-f urls.txt] [url ...]"; exit 1; }

mkdir -p "$OUTPUT_DIR"

extract_sproutvideo_url() {
  python3 -c "
import json, glob, re, sys
for f in glob.glob('*patreon.com*api*posts*.dump'):
    with open(f) as fh:
        data = json.load(fh)
    html = data.get('data',{}).get('attributes',{}).get('embed',{}).get('html','')
    m = re.search(r'src=https?%3A%2F%2Fvideos\.sproutvideo\.com%2Fembed%2F([^&]+)', html)
    if m:
        print(f'https://videos.sproutvideo.com/embed/{m.group(1).replace(\"%2F\",\"/\")}')
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

download_one() {
  local url="$1"
  local filename=$(echo "$url" | sed 's|.*/posts/||;s|[?#].*||')

  # 跳过已下载
  if ls "${OUTPUT_DIR}/${filename}".* >/dev/null 2>&1; then
    echo "[跳过] ${filename}"
    return 0
  fi

  echo "[下载] ${filename}"

  # 策略1: 有密码时先尝试直接下载
  if [[ -n "$PASSWORD" ]]; then
    if yt-dlp --cookies-from-browser chrome --impersonate chrome \
      --video-password "$PASSWORD" \
      -o "${OUTPUT_DIR}/${filename}.%(ext)s" \
      "$url" 2>&1; then
      echo "[成功] ${filename} (密码)"
      return 0
    fi
    echo "  密码方式失败, 尝试 SproutVideo 直链..."
  fi

  # 策略2: 从 API 提取 SproutVideo 直链 (免密码)
  local tmpdir=$(mktemp -d)
  pushd "$tmpdir" > /dev/null
  yt-dlp --cookies-from-browser chrome --impersonate chrome \
    --write-pages --skip-download "$url" 2>&1 || true

  local sprout_url=$(extract_sproutvideo_url)
  popd > /dev/null
  rm -rf "$tmpdir"

  if [[ -n "$sprout_url" ]]; then
    yt-dlp --cookies-from-browser chrome --impersonate chrome \
      --referer "https://www.patreon.com/" \
      -o "${OUTPUT_DIR}/${filename}.%(ext)s" \
      "$sprout_url" && echo "[成功] ${filename} (直链)" || echo "[失败] ${filename}"
  else
    yt-dlp --cookies-from-browser chrome --impersonate chrome \
      -o "${OUTPUT_DIR}/${filename}.%(ext)s" \
      "$url" && echo "[成功] ${filename}" || echo "[失败] ${filename}"
  fi
}

for url in "${URLS[@]}"; do
  download_one "$url"
done
