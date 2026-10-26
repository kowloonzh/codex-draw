#!/usr/bin/env bash
# 用 Codex CLI 内置生图工具画图，输出到指定 PNG。
set -euo pipefail

usage() { echo "用法: draw.sh -p <提示词> [-o 输出.png] [-i 参考图 ...]" >&2; exit 2; }

prompt="" out="" images=()
while getopts "p:o:i:h" opt; do
  case $opt in
    p) prompt=$OPTARG ;;
    o) out=$OPTARG ;;
    i) images+=("$OPTARG") ;;
    *) usage ;;
  esac
done
[[ -z $prompt ]] && usage
command -v codex >/dev/null || { echo "未找到 codex 命令" >&2; exit 1; }

out=${out:-"$PWD/codex-draw-$(date +%Y%m%d-%H%M%S).png"}
mkdir -p "$(dirname "$out")"
out="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")"

img_args=()
for f in ${images[@]+"${images[@]}"}; do
  [[ -f $f ]] || { echo "参考图不存在: $f" >&2; exit 1; }
  img_args+=(-i "$f")
done

gen_dir="${CODEX_HOME:-$HOME/.codex}/generated_images"
mkdir -p "$gen_dir"
marker=$(mktemp)
trap 'rm -f "$marker"' EXIT

ref_note=""
(( ${#img_args[@]} )) && ref_note="以附带的图片作为参考图进行编辑。"

instruction="请调用你的内置图像生成工具画图，只生成一张。${ref_note}
画面要求：${prompt}
生成后把图片文件复制到：${out}
不要做其他任何事情，完成后只回复保存路径。"

codex exec --skip-git-repo-check -s workspace-write \
  -C "$(dirname "$out")" ${img_args[@]+"${img_args[@]}"} -- "$instruction" >&2 </dev/null

# Codex 没复制成功时，取本次运行期间新生成的最新图片
if [[ ! -s $out ]]; then
  latest=$(find "$gen_dir" -type f -name '*.png' -newer "$marker" -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null | head -1 || true)
  [[ -n $latest ]] || { echo "未生成图片" >&2; exit 1; }
  cp "$latest" "$out"
fi

echo "SAVED: $out"
