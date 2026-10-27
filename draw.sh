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

codex_home="${CODEX_HOME:-$HOME/.codex}"
gen_dir="$codex_home/generated_images"
# 空 HOME：让 Codex 不扫描 ~/.agents/skills 等用户级 skill（登录信息在 CODEX_HOME，不受影响）
clean_home="${TMPDIR:-/tmp}/codex-draw-home"
mkdir -p "$clean_home"
log=$(mktemp)
trap 'rm -f "$log"' EXIT

ref_note=""
(( ${#img_args[@]} )) && ref_note="以附带的图片作为参考图进行编辑。"

# 只让 Codex 生图，不让它复制文件（省一轮模型调用）
instruction="调用内置图像生成工具生成一张图，不要做其他任何事情。${ref_note}
画面要求：${prompt}"

# 省 token：
# - 轻量模型 + 低推理（只负责调用生图工具，不需要强模型）
# - --ignore-user-config 跳过用户 config.toml 里的 MCP 服务器和插件，大幅缩小每轮上下文
# - 空 HOME 跳过用户级 skill 列表，进一步缩小上下文
# - 输出写入临时日志，不灌进调用方（Claude）的上下文
model=${CODEX_DRAW_MODEL:-gpt-6-luna}
effort=${CODEX_DRAW_EFFORT:-low}

status=0
CODEX_HOME="$codex_home" HOME="$clean_home" \
  codex exec --skip-git-repo-check --ignore-user-config --json \
  -m "$model" -c model_reasoning_effort="$effort" -s read-only \
  -C "$(dirname "$out")" ${img_args[@]+"${img_args[@]}"} -- "$instruction" \
  >"$log" 2>&1 </dev/null || status=$?

thread=$(grep -o '"thread_id":"[^"]*"' "$log" | head -1 | cut -d'"' -f4 || true)
latest=""
[[ -n $thread && -d $gen_dir/$thread ]] && \
  latest=$(ls -t "$gen_dir/$thread"/*.png 2>/dev/null | head -1 || true)

if [[ -z $latest ]]; then
  echo "未生成图片（codex 退出码 ${status}）" >&2
  grep -oE '"message":"[^"]*"' "$log" | tail -3 >&2 || tail -5 "$log" >&2
  exit 1
fi
cp "$latest" "$out"

echo "SAVED: $out"
