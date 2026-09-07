#!/usr/bin/env bash
# Push local config changes to main via a pull request (protected main).
# 因为 main 有 required_status_checks 分支保护,直接 `git push origin main`
# 会被拒;本脚本把 "提交 → 推 feature 分支 → 开 PR → 自动合并 → 删分支" 串成一条命令。
#
# 用法:
#   ./lib/scripts/pr.sh "commit message"          # 开 PR 并设自动合并(CI 绿后自动合并+删分支)
#   ./lib/scripts/pr.sh --no-auto "commit message" # 只开 PR,不加自动合并(手动合并)
#
# 说明:
#   - 会提交当前所有改动(git add -A,含新增未跟踪文件);只应在准备推送全部改动时运行。
#   - 基于最新 origin/main 建分支,不影响的本地未提交改动会被带过去。
#   - 需要 gh 已登录且仓库已启用 allow_auto_merge;CI 构建通过后才会实际合并。

set -euo pipefail
cd "$(dirname "$0")/../.."

# ---- 参数 ----
AUTO=1
if [[ ${1:-} == "--no-auto" ]]; then
  AUTO=0
  shift
fi
MSG="${1:-}"
if [[ -z $MSG ]]; then
  echo "用法: $0 [--no-auto] \"commit message\""
  exit 1
fi

# ---- 前置检查 ----
command -v gh >/dev/null || {
  echo "❌ 未找到 gh"
  exit 1
}
gh auth status >/dev/null 2>&1 || {
  echo "❌ gh 未登录"
  exit 1
}
git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "❌ 不在 git 仓库内"
  exit 1
}

# ---- 空改动检查 ----
if [[ -z "$(git status --porcelain)" ]]; then
  echo "⚠️ 没有未提交的改动,无需开 PR"
  exit 0
fi

ORIG_BRANCH="$(git branch --show-current)"

# ---- 分支名(由 commit message 生成 slug + 时间戳保证唯一) ----
slug="$(echo "$MSG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-\+//; s/-\+$//')"
[[ -z $slug ]] && slug="change"
branch="pr/$slug-$(date +%s)"

echo "=== [1/5] 拉取最新 main ==="
git fetch origin --quiet

echo "=== [2/5] 基于 origin/main 建分支 $branch (带走本地改动) ==="
# stash 未提交改动 → 切到新分支(基于最新 main) → pop 回来
# intent-to-add (git add -N) 的新文件会让 `git stash push -u` 报
# "Entry '...' not uptodate. Cannot merge." —— -N 条目在 index 里只占空 blob。
# 先用 `git add -u` 把它们提升为完整暂存条目(它们已在 index 中, 属已跟踪文件),
# stash 才能处理; 后续 commit 本就是 git add -A, 提前 stage 无副作用。
git add -u
git stash push -u -m "pr-script-wip" >/dev/null
git switch -c "$branch" origin/main
if ! git stash pop; then
  echo "❌ 本地改动与最新 origin/main 冲突,请手动解决后再运行"
  exit 1
fi

echo "=== [3/5] 提交并推送分支 ==="
git add -A
git commit -m "$MSG" >/dev/null
git push -u origin "$branch" 2>&1 | tail -2

echo "=== [4/5] 开 PR 到 main ==="
pr_url="$(gh pr create --repo ainnhuomiao/mynixos-config --base main --head "$branch" --title "$MSG" --body "自动生成: \`${branch}\` 已推送到 main。CI 通过后可合并。")"
pr_num="$(echo "$pr_url" | sed -n 's|.*/pull/\([0-9]*\).*|\1|p')"
echo "   PR: $pr_url"

if [[ $AUTO == "1" ]]; then
  echo "=== [5/5] 设自动合并 ==="
  gh pr merge "$pr_num" --repo ainnhuomiao/mynixos-config --auto --merge --delete-branch
  echo "   已挂自动合并: CI(Build NixOS x86_64-linux) 通过后自动合并且删 $branch"
else
  echo "=== [5/5] 跳过自动合并(手动合并) ==="
fi

# ---- 切回原分支 ----
git switch "$ORIG_BRANCH" >/dev/null 2>&1 || true

echo
echo "✅ 完成。PR: $pr_url"
echo "   本地可删分支: git branch -D $branch"
