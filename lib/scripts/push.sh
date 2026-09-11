#!/usr/bin/env bash
# 提交并推送配置改动。
#
# 核心约定:只提交**已暂存(git add / git apply --cached)的改动**,工作区里未暂存的
# 内容(常见:用户正在改的 WIP)一律不动、不提交 —— 不再有 git add -A 扫全树的隐患。
# 所以:先 git add 你要提交的文件,再运行本脚本。
#
# 用法:
#   ./lib/scripts/push.sh "commit message"     # 提交已暂存改动并直推当前分支(通常 main)
#   ./lib/scripts/push.sh --pr "msg"           # 基于 origin/main 建分支、提交、开 PR(不合并)
#   ./lib/scripts/push.sh --pr --merge "msg"   # 开 PR 并立即合并(留一条 PR 记录)
#
# 说明:
#   - main 自 2026-09-12 起允许直推(ruleset 仅保留 deletion + non_fast_forward),
#     默认路径不再需要 PR;--pr 只在想要评审/记录时使用。
#   - 无 required status checks 后 `gh pr merge --auto` 会立即合并,故这里用显式 --merge。

set -euo pipefail
cd "$(dirname "$0")/../.."

# ---- 参数 ----
PR=0
MERGE=0
MSG=""
for arg in "$@"; do
  case "$arg" in
  --pr) PR=1 ;;
  --merge) MERGE=1 ;;
  -*) echo "❌ 未知参数: $arg (可用: --pr --merge)" && exit 1 ;;
  *) MSG="$arg" ;;
  esac
done
[[ -n $MSG ]] || {
  echo '用法: push.sh [--pr] [--merge] "commit message"'
  exit 1
}
[[ $MERGE == 0 || $PR == 1 ]] || {
  echo "❌ --merge 需要与 --pr 一起使用"
  exit 1
}

git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "❌ 不在 git 仓库内"
  exit 1
}

# ---- 只认已暂存内容 ----
if git diff --cached --quiet; then
  echo "❌ 没有已暂存的改动 —— 本脚本只提交已暂存内容,不会 git add -A 扫走工作区 WIP。"
  echo "   先 git add <文件>(或 git apply --cached <patch>),再运行。"
  exit 1
fi

ORIG="$(git branch --show-current)"
echo "=== 待提交(已暂存) ==="
git diff --cached --stat

if [[ $PR == 0 ]]; then
  echo "=== 提交并直推 origin/$ORIG ==="
  git commit -m "$MSG"
  git push origin "$ORIG"
  echo
  echo "✅ 已推送 origin/$ORIG;CI(nix.yml)会在推送后构建并推缓存"
  exit 0
fi

# ---- 可选 PR 流程 ----
command -v gh >/dev/null || {
  echo "❌ 未找到 gh(--pr 模式需要)"
  exit 1
}
gh auth status >/dev/null 2>&1 || {
  echo "❌ gh 未登录"
  exit 1
}

slug="$(printf '%s' "$MSG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-\+//; s/-\+$//')"
[[ -n $slug ]] || slug="change"
branch="pr/$slug-$(date +%s)"

echo "=== 基于 origin/main 建分支 $branch(带走已暂存改动与未暂存 WIP) ==="
git fetch origin --quiet
git switch --no-track -c "$branch" origin/main
git commit -m "$MSG"
git push -u origin "$branch" 2>&1 | tail -2

echo "=== 创建 PR ==="
pr_url="$(gh pr create --repo ainnhuomiao/mynixos-config --base main --head "$branch" \
  --title "$MSG" --body "由 \`lib/scripts/push.sh --pr\` 创建;分支 \`$branch\`。")"
echo "   $pr_url"

if [[ $MERGE == 1 ]]; then
  echo "=== 合并 PR 并同步本地 main ==="
  gh pr merge "${pr_url##*/}" --repo ainnhuomiao/mynixos-config --merge --delete-branch
  git fetch origin main:main
  if git switch "$ORIG" >/dev/null 2>&1; then
    echo
    echo "✅ 已合并并删除远端分支;本地 $ORIG 已同步到含该提交的 origin/main"
  else
    echo
    echo "⚠️ 已合并并删除远端分支,但切回 $ORIG 失败(工作区有冲突改动?)"
    echo "   当前仍在 $branch;改动已包含在 origin/main: git fetch origin main:main 后手动处理"
  fi
else
  echo
  echo "✅ PR 已创建: $pr_url"
  echo "   改动已提交在分支 $branch 上,本地停留在此分支(你的文件内容是含本次改动的版本)。"
  echo "   合并后回到 main:  git fetch origin main:main && git switch main"
  echo "   关闭本 PR 并放弃: gh pr close ${pr_url##*/} --delete-branch && git switch main && git branch -D $branch"
fi
