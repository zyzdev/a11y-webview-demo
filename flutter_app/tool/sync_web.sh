#!/usr/bin/env bash
# 把專案根目錄的 web/ 同步到 flutter_app/assets/web/（App 內建伺服器從這裡提供網頁）。
# 改過 web/ 之後要執行，test/assets_sync_test.dart 會檢查兩邊是否一致。
#
# 用法：flutter_app/tool/sync_web.sh（從任何目錄執行都可以，路徑以這個腳本的位置為準）。
set -euo pipefail

app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_dir="$(cd "$app_dir/.." && pwd)/web"
dest_dir="$app_dir/assets/web"

# 有 --delete，路徑錯了會刪錯東西，所以先確認位置正確。
if [[ ! -f "$app_dir/pubspec.yaml" ]]; then
  echo "sync_web.sh: 找不到 $app_dir/pubspec.yaml，腳本應該位在 flutter_app/tool/ 底下" >&2
  exit 1
fi
if [[ ! -f "$src_dir/index.html" ]]; then
  echo "sync_web.sh: 找不到網頁來源 $src_dir/index.html" >&2
  exit 1
fi

mkdir -p "$dest_dir"
rsync -a --delete --exclude .DS_Store "$src_dir/" "$dest_dir/"
echo "已同步 $src_dir/ → $dest_dir/"
