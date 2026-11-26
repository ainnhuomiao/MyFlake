#!/usr/bin/env python3
"""自动检测并替换本仓库 .nix 文件中失配的固定输出哈希。"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from pathlib import Path
import re
import socket
import subprocess
import sys

FAKE_HASH = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
ANSI_RE = re.compile(
    r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)"
)
HASH_MISMATCH_RE = re.compile(
    r"error:\s+hash mismatch in fixed-output derivation\s+'([^']+)':\s*\r?\n"
    r"\s*specified:\s+(\S+)\s*\r?\n"
    r"\s*got:\s+(\S+)",
    re.MULTILINE,
)
FAKE_ATTR_RE = re.compile(r"\b(?:pkgs\.)?lib\.fake(?:Hash|Sha256)\b")
EMPTY_ATTR_RE = re.compile(
    r'\b(?:hash|sha256|vendorHash|cargoHash|npmDepsHash|pnpmDepsHash)\s*=\s*("")'
)


@dataclass(frozen=True)
class HashMatch:
    """单个哈希匹配位置及其替换内容。"""

    path: Path
    line: int
    start: int
    end: int
    new_text: str


@dataclass(frozen=True)
class Replacement:
    """已应用或待预览的哈希替换记录。"""

    drv: str
    path: Path
    line: int
    specified: str
    got: str


@dataclass(frozen=True)
class ExternalMismatch:
    """未在本仓库 .nix 中找到的外部/上游哈希失配。"""

    drv: str
    specified: str
    got: str


@dataclass(frozen=True)
class AmbiguousMismatch:
    """存在多处匹配或同源冲突、无法自动定位的哈希失配。"""

    drvs: list[str]
    specified: str
    gots: list[str]
    locations: list[tuple[Path, int]]


@dataclass
class RoundReport:
    """单轮检测与替换汇总结果。"""

    replacements: list[Replacement] = field(default_factory=list)
    external: list[ExternalMismatch] = field(default_factory=list)
    ambiguous: list[AmbiguousMismatch] = field(default_factory=list)


def default_target() -> str:
    """按环境变量或主机名确定默认构建目标。"""
    host = os_host()
    return f".#nixosConfigurations.{host}.config.system.build.toplevel"


def os_host() -> str:
    """优先使用 NH_HOST，否则匹配本机主机名，其余回退到 nixos。"""
    import os

    env_host = os.environ.get("NH_HOST", "").strip()
    if env_host:
        return env_host
    hostname = socket.gethostname().strip()
    if hostname in {"nixos", "nixos-wsl"}:
        return hostname
    return "nixos"


def parse_mismatches(output: str) -> list[tuple[str, str, str]]:
    """剥离 ANSI 转义序列并提取 (drv, specified, got) 列表。"""
    clean = ANSI_RE.sub("", output).replace("\r", "")
    return [(m.group(1), m.group(2), m.group(3)) for m in HASH_MISMATCH_RE.finditer(clean)]


def git_tracked_nix_files(repo_root: Path) -> list[Path]:
    """返回仓库内所有 git 跟踪的 .nix 文件（含 git add -N 新文件）。"""
    proc = subprocess.run(
        ["git", "ls-files", "-z", "--", "*.nix"],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    raw_paths = proc.stdout.decode("utf-8").split("\0")
    files: list[Path] = []
    for rel in raw_paths:
        if not rel:
            continue
        candidate = repo_root / rel
        if candidate.is_file():
            files.append(candidate)
    return files


def _line_number(content: str, offset: int) -> int:
    return content.count("\n", 0, offset) + 1


def find_matches(nix_files: list[Path], specified: str, got: str) -> list[HashMatch]:
    """在仓库 .nix 文件中查找 specified 对应的精确字面量或占位符。"""
    literal = f'"{specified}"'
    literal_re = re.compile(re.escape(literal))
    replacement = f'"{got}"'

    matches: list[HashMatch] = []
    contents: dict[Path, str] = {}
    for path in nix_files:
        text = path.read_text(encoding="utf-8")
        contents[path] = text
        for m in literal_re.finditer(text):
            matches.append(
                HashMatch(
                    path=path,
                    line=_line_number(text, m.start()),
                    start=m.start(),
                    end=m.end(),
                    new_text=replacement,
                )
            )

    if matches or specified != FAKE_HASH:
        return matches

    for path, text in contents.items():
        for m in FAKE_ATTR_RE.finditer(text):
            matches.append(
                HashMatch(
                    path=path,
                    line=_line_number(text, m.start()),
                    start=m.start(),
                    end=m.end(),
                    new_text=replacement,
                )
            )
        for m in EMPTY_ATTR_RE.finditer(text):
            matches.append(
                HashMatch(
                    path=path,
                    line=_line_number(text, m.start(1)),
                    start=m.start(1),
                    end=m.end(1),
                    new_text=replacement,
                )
            )

    return matches


def apply_round(
    nix_files: list[Path],
    mismatches: list[tuple[str, str, str]],
    dry_run: bool,
) -> RoundReport:
    """对一轮构建中的所有哈希失配进行去重、安全分类并执行替换。"""
    grouped: dict[str, list[tuple[str, str]]] = {}
    for drv, specified, got in mismatches:
        grouped.setdefault(specified, []).append((drv, got))

    report = RoundReport()
    pending_edits: list[tuple[HashMatch, Replacement]] = []

    for specified, entries in grouped.items():
        drvs = list(dict.fromkeys(drv for drv, _ in entries))
        gots = list(dict.fromkeys(got for _, got in entries))
        if len(gots) > 1:
            locs = [(m.path, m.line) for m in find_matches(nix_files, specified, gots[0])]
            report.ambiguous.append(
                AmbiguousMismatch(
                    drvs=drvs,
                    specified=specified,
                    gots=gots,
                    locations=locs,
                )
            )
            continue

        got = gots[0]
        matches = find_matches(nix_files, specified, got)
        if not matches:
            report.external.append(
                ExternalMismatch(drv=drvs[0], specified=specified, got=got)
            )
            continue

        if len(matches) > 1:
            report.ambiguous.append(
                AmbiguousMismatch(
                    drvs=drvs,
                    specified=specified,
                    gots=[got],
                    locations=[(m.path, m.line) for m in matches],
                )
            )
            continue

        match = matches[0]
        rep = Replacement(
            drv=drvs[0],
            path=match.path,
            line=match.line,
            specified=specified,
            got=got,
        )
        report.replacements.append(rep)
        pending_edits.append((match, rep))

    if not dry_run and pending_edits:
        _write_edits(pending_edits)

    return report


def _write_edits(edits: list[tuple[HashMatch, Replacement]]) -> None:
    by_path: dict[Path, list[HashMatch]] = {}
    for match, _ in edits:
        by_path.setdefault(match.path, []).append(match)

    for path, file_matches in by_path.items():
        text = path.read_text(encoding="utf-8")
        # 同一文件内按偏移倒序替换，避免前一次替换破坏后续区间坐标。
        ordered = sorted(file_matches, key=lambda m: (m.start, m.end), reverse=True)
        prev_start = len(text) + 1
        for m in ordered:
            if m.end > prev_start:
                raise ValueError(f"检测到重叠替换区间: {path}:{m.line}")
            text = text[: m.start] + m.new_text + text[m.end :]
            prev_start = m.start
        path.write_text(text, encoding="utf-8")


def run_nix_build(targets: list[str], repo_root: Path) -> tuple[int, str]:
    """执行 nix build 并实时透传输出，返回退出码和完整日志文本。"""
    cmd = ["nix", "build", "--no-link", "--keep-going", "--fallback", *targets]
    proc = subprocess.Popen(
        cmd,
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    assert proc.stdout is not None
    lines: list[str] = []
    for line in proc.stdout:
        sys.stderr.write(line)
        sys.stderr.flush()
        lines.append(line)
    rc = proc.wait()
    return rc, "".join(lines)


def _rel(path: Path, repo_root: Path) -> str:
    try:
        return str(path.relative_to(repo_root))
    except ValueError:
        return str(path)


def _print_round_report(report: RoundReport, repo_root: Path, dry_run: bool) -> None:
    if report.replacements:
        action = "预计替换" if dry_run else "已替换"
        print(f"\n[fix-hashes] {action} {len(report.replacements)} 处本地哈希:")
        for rep in report.replacements:
            print(
                f"  - {_rel(rep.path, repo_root)}:{rep.line} "
                f"({Path(rep.drv).name}): {rep.specified} -> {rep.got}"
            )

    if report.external:
        print(
            f"\n[fix-hashes] 发现 {len(report.external)} 处外部/上游哈希失配"
            "（不在本仓库 .nix 文件中，属上游 nixpkgs 或 flake input，已跳过；"
            "请勿手改，应检查二进制缓存或更新对应 input）:"
        )
        for ext in report.external:
            print(f"  - {ext.drv}: specified={ext.specified} got={ext.got}")

    if report.ambiguous:
        print(
            f"\n[fix-hashes] 发现 {len(report.ambiguous)} 处多处匹配或冲突哈希"
            "（为避免误改已跳过，请人工确认）:"
        )
        for amb in report.ambiguous:
            drv_list = ", ".join(Path(d).name for d in amb.drvs)
            got_list = ", ".join(amb.gots)
            loc_list = ", ".join(f"{_rel(p, repo_root)}:{ln}" for p, ln in amb.locations)
            print(
                f"  - [{drv_list}] specified={amb.specified} got=[{got_list}]"
                f" 匹配位置: {loc_list or '无'}"
            )


def _show_git_diff(repo_root: Path, modified_files: set[Path]) -> None:
    if not modified_files:
        return
    rels = sorted(_rel(p, repo_root) for p in modified_files)
    print("\n[fix-hashes] 本次修改汇总 (git diff):")
    subprocess.run(["git", "diff", "--", *rels], cwd=repo_root, check=False)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(
        prog="fix-hashes.py",
        description="自动构建目标并替换本仓库 .nix 文件中失配的固定输出哈希。",
    )
    parser.add_argument(
        "targets",
        nargs="*",
        help="要构建的 flake installable（默认构建当前主机系统闭包）",
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="仅检测并打印计划替换项，不写入任何文件",
    )
    parser.add_argument(
        "--from-log",
        type=Path,
        help="先从已有构建日志解析并修复本地哈希；若成功替换再启动构建校验",
    )
    parser.add_argument(
        "--max-rounds",
        type=int,
        default=5,
        help="多阶段哈希（如 src -> vendorHash/pnpmDepsHash）最大迭代轮数（默认: 5）",
    )
    args = parser.parse_args(argv)
    if args.max_rounds < 1:
        parser.error("--max-rounds 必须 >= 1")
    return args


def _process_mismatches(
    repo_root: Path,
    mismatches: list[tuple[str, str, str]],
    modified_files: set[Path],
    dry_run: bool,
) -> RoundReport:
    nix_files = git_tracked_nix_files(repo_root)
    report = apply_round(nix_files, mismatches, dry_run=dry_run)
    _print_round_report(report, repo_root, dry_run=dry_run)
    if not dry_run:
        for rep in report.replacements:
            modified_files.add(rep.path)
    return report


def main(argv: list[str] | None = None) -> int:
    """脚本入口：循环构建并自动修复本地哈希失配。"""
    args = parse_args(argv)
    repo_root = Path(__file__).resolve().parent.parent
    targets = args.targets or [default_target()]
    modified_files: set[Path] = set()

    if args.from_log is not None:
        if not args.from_log.is_file():
            print(f"[fix-hashes] 日志文件不存在: {args.from_log}", file=sys.stderr)
            return 1
        initial_log = args.from_log.read_text(encoding="utf-8", errors="replace")
        mismatches = parse_mismatches(initial_log)
        if not mismatches:
            print(
                f"[fix-hashes] 日志中未检测到固定输出哈希失配: {args.from_log}",
                file=sys.stderr,
            )
            return 1
        report = _process_mismatches(
            repo_root, mismatches, modified_files, dry_run=args.dry_run
        )
        if args.dry_run:
            return 0 if not report.external and not report.ambiguous else 1
        if not report.replacements:
            print("[fix-hashes] 日志中无可自动替换的本地哈希，停止。", file=sys.stderr)
            return 1

    for round_idx in range(1, args.max_rounds + 1):
        print(
            f"[fix-hashes] 第 {round_idx}/{args.max_rounds} 轮构建: "
            + " ".join(targets)
        )
        rc, output = run_nix_build(targets, repo_root)
        if rc == 0:
            print("[fix-hashes] 构建成功。")
            _show_git_diff(repo_root, modified_files)
            return 0

        mismatches = parse_mismatches(output)
        if not mismatches:
            print(
                f"[fix-hashes] 构建失败（退出码 {rc}），但未检测到固定输出哈希失配。",
                file=sys.stderr,
            )
            _show_git_diff(repo_root, modified_files)
            return rc

        report = _process_mismatches(
            repo_root, mismatches, modified_files, dry_run=args.dry_run
        )

        if args.dry_run:
            return 0 if not report.external and not report.ambiguous else 1

        if not report.replacements:
            print("[fix-hashes] 本轮无可自动替换的本地哈希，停止。", file=sys.stderr)
            _show_git_diff(repo_root, modified_files)
            return 1

    print(
        f"[fix-hashes] 已达到最大迭代轮数 ({args.max_rounds})，构建仍未完全通过。",
        file=sys.stderr,
    )
    _show_git_diff(repo_root, modified_files)
    return 1


if __name__ == "__main__":
    sys.exit(main())
