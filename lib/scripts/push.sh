#!/usr/bin/env bash
# 提交并推送配置改动。
#
# 三种用法(默认最安全:只提交**已暂存**内容,不会顺手带走工作区的 WIP):
#   ./lib/scripts/push.sh "msg"                 # 提交已暂存(git add)的内容并直推当前分支
#   ./lib/scripts/push.sh "msg" <路径...>        # 直接指定要提交的文件/目录(内部替你 git add)
#   ./lib/scripts/push.sh --all "msg"           # 一键:git add -A(含未跟踪文件)后提交直推
#   ./lib/scripts/push.sh --pr [--merge] "msg"  # 可选 PR 流程(建分支开 PR;--merge 立即合并)
#
# 说明:
#   - main 自 2026-09-12 起允许直推(ruleset 仅保留 deletion + non_fast_forward),默认不需要 PR。
#   - --all 会把当时工作区里**所有**改动一起提交(包括你还没写完的 WIP),按需使用。
#   - 无 required status checks 后 `gh pr merge --auto` 会立即合并,故这里用显式 --merge。

set -euo pipefail
cd "$(dirname "$0")/../.."

# ---- 参数 ----
PR=0
MERGE=0
ALL=0
MSG=""
PATHS=()
for arg in "$@"; do
  case "$arg" in
  --pr) PR=1 ;;
  --merge) MERGE=1 ;;
  --all) ALL=1 ;;
  -*) echo "❌ 未知参数: $arg (可用: --pr --merge --all)" && exit 1 ;;
  *)
    if [[ -z $MSG ]]; then
      MSG="$arg"
    else
      PATHS+=("$arg")
    fi
    ;;
  esac
done
[[ -n $MSG ]] || {
  echo '用法: push.sh [--pr] [--merge] [--all] "commit message" [路径...]'
  exit 1
}
[[ $MERGE == 0 || $PR == 1 ]] || {
  echo "❌ --merge 需要与 --pr 一起使用"
  exit 1
}
[[ ${#PATHS[@]} == 0 || $ALL == 0 ]] || {
  echo "❌ --all 与显式路径不能同时使用"
  exit 1
}

git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "❌ 不在 git 仓库内"
  exit 1
}

# ---- 决定暂存哪些内容 ----
if [[ ${#PATHS[@]} -gt 0 ]]; then
  echo "=== 暂存指定路径 ==="
  git add -- "${PATHS[@]}"
elif [[ $ALL == 1 ]]; then
  echo "=== 暂存工作区全部改动(git add -A,含未跟踪文件) ==="
  git add -A
fi

if git diff --cached --quiet; then
  echo "❌ 没有可提交的改动。"
  echo '   push.sh "msg"            # 提交已 git add 的内容'
  echo '   push.sh "msg" <路径...>   # 直接指定文件(替你 git add)'
  echo '   push.sh --all "msg"      # 一键提交工作区全部改动'
  exit 1
fi

ORIG="$(git branch --show-current)"
echo "=== 待提交 ==="
git diff --cached --stat

if [[ $ALL == 0 ]]; then
  rest_tracked="$(git diff --name-only | wc -l | tr -d ' ')"
  rest_untracked="$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')"
  if [[ $rest_tracked != 0 || $rest_untracked != 0 ]]; then
    echo "ℹ️ 未包含在本次提交: 未暂存改动 $rest_tracked 个文件, 未跟踪文件 $rest_untracked 个"
  fi
fi

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
