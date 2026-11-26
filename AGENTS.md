# AGENTS.md

Personal NixOS flake for one dual-boot machine: bare-metal host `nixos` and Windows WSL2 host `nixos-wsl`, user `huomiao`, `x86_64-linux` only, built with flake-parts. This working copy is the live `nixos` host, so switching `nixos` affects it immediately.

`README.md` is a Chinese user manual; if it ever disagrees with the flake outputs, trust `nix flake show` and the code.

## Commands

Run from the repo root. Typical loop: edit, `git add` new files, `just format`, `just check`.

- `just format`: `nix fmt` (treefmt: nixfmt, prettier for Markdown/YAML/JSON, shfmt, stylua). Rewrites files in place across the repo.
- `just check`: `nix flake check --fallback`. Evaluates every output, including the NixOS config, and builds the `treefmt` and `disko-layouts` checks. It does not build `packages`.
- `just build [host]`: builds a NixOS system without activating it (defaults to `nixos` or `nixos-wsl` based on hostname). CI never builds the system closure, so this is the only full system check.
- `just fix-hashes [args...]`: runs `scripts/fix-hashes.py` to auto-replace mismatched fixed-output hashes in git-tracked `.nix` files (skips upstream/nixpkgs hashes; supports `--dry-run` and custom targets such as `.#dingtalk`).
- `just wsl-tarball [out]`: builds an importable `.wsl` tarball for `nixos-wsl` using `NixOS-WSL`'s `tarballBuilder`.
- Single check: `nix build --no-link .#checks.x86_64-linux.treefmt` (formatting) or `.#checks.x86_64-linux.disko-layouts` (pure eval of `lib/disko-layout/`).
- Single package: `nix build --no-link .#<name>` for names in `nix flake show`. Overlay-only packages such as `omp-provider` build via `.#nixosConfigurations.nixos.pkgs.omp-provider`.
- Eval one option without building: `nix eval .#nixosConfigurations.nixos.config.<path>`.
- There is no test suite. Verification is the checks above.
- `just build` can run for a long time because it builds the whole system closure. Use a long timeout or run it in the background.
- Substituter errors in `just check` output, such as an unreachable substituter, are logged and ignored because of `--fallback`. Trust the exit code.
- Run `just format` before `just check`. `just verify` follows this order; `just rebuild-switch` runs check first, so unformatted files fail it.

## Requires explicit user request

- Committing or pushing. `just push`, `push-all`, `pr`, and `pr-merge` push to `origin`. Pushes to `main` trigger CI, which uploads to Attic. `push-all` also stages untracked files.
- `just disko` and `just install`: destructive installer steps.
- `just clean`: irreversibly deletes old generations and GC roots.
- `just rebuild-switch-fast`: skips checks.

## Live switch

- `just rebuild-switch` is allowed only after `just check` passes. It activates this machine immediately, because sudo is passwordless (`system/base/security.nix`).

## Gotchas

- Flakes see only git-tracked files. A new file that isn't `git add`ed (or at least `git add -N`) makes evaluation fail with a missing-path error.
- `just format` rewrites any unformatted file in the repo, including unrelated WIP. Check `git status` and `git diff` afterwards.

## Architecture

- `flake.nix` declares inputs and `nixConfig`. Outputs come from `flake/modules/` (packages, checks, dev shells, formatter, overlays) and `hosts/`.
- `flake/nixpkgs.nix` is the single source of truth for nixpkgs `config` and the shared overlay list (`pkgs/` + `overlays/`), imported directly by `system/nix/nixpkgs.nix`, `flake/modules/packages.nix`, and `flake/modules/overlays.nix` (`perSystem` cannot reference `inputs.self.overlays` without infinite recursion). NixOS adds `rust-overlay` in `system/nix/nixpkgs.nix`.
- `hosts/default.nix` builds `nixosConfigurations.nixos` (from `hosts/nixos/`, `system/`, disko, ncro, niri, and `home/`) and `nixosConfigurations.nixos-wsl` (from `hosts/nixos-wsl/`, `system/base/common.nix`, `system/nix/`, ncro, `nixos-wsl`, and `home/wsl.nix`).
- `hosts/nixos/` holds machine-specific hardware and tuning (`hardware-configuration.nix`, `hardware.nix`, `egpu.nix`, `tuning.nix`). `hosts/nixos-wsl/` holds WSL2-specific config (`useWindowsDriver`, WSLg fonts/clipboard, `nix-ld` GPU libs, `wsl-open`).
- `system/` holds NixOS modules grouped by domain: `base/`, `desktop/` (`niri-session.nix`, `audio.nix`, `fonts.nix`, `packages.nix`), `network/` (`network.nix`, `proxy/` with `tools.nix`/`rules.nix`/scripts), `apps/`, and `nix/` (`cache.nix` combines substituters + ncro).
- `home/` holds Home Manager modules grouped by domain (`shell/`, `cli/`, `desktop/`, `editors/`, `media/`, `apps/`, `network/`, `dev/`, `ai/`), imported directly by `home/default.nix`. Plain GUI/user packages go in `home/apps/apps.nix`. Single-file modules use `foo.nix`; multi-file or asset-bearing modules use `foo/default.nix`.
- `me` (`me.nix`) and `appearance` (`lib/appearance.nix`) are specialArgs in all modules. Use them instead of importing `me.nix` or hardcoding colors and fonts.
- `pkgs/` holds local packages (`<name>/default.nix`, overlay in `pkgs/default.nix`). `overlays/` holds nixpkgs patches. `lib/` holds pure Nix helpers/data (`appearance.nix`, `disko-layout/`). `scripts/` holds helper shell scripts invoked by `justfile`.

## Deliberate choices, don't "clean up"

- Input wiring is deliberate, and comments in `flake.nix` say why. `noctalia` follows host nixpkgs because a bundled older glibc crashes at startup. `emanote`, `herdr`, and `llm-agents` keep their own nixpkgs pins.
- Bumping `noctalia` also means bumping `officialPlugins.rev` in `home/desktop/noctalia/default.nix`.
- `packages` outputs are deliberately limited to the fixed CI cache candidates plus `disko`. Vendor apps belong in `home/` or overlays. `nix flake check` doesn't build `packages`; CI combines them with packages installed directly by NixOS and Home Manager in `legacyPackages.cacheOutputs`, deduplicates them by derivation, then uses `nix-fast-build --skip-cached` to build only cache misses.
- To guarantee that a source-built package enters the Attic cache, add it to `flake/modules/packages.nix`. Packages already installed directly by NixOS or Home Manager are discovered automatically; the full system toplevel is deliberately excluded.
- sing-box is not started at boot (`system/network/proxy/default.nix`, `wantedBy = []`). Manage it with `sing-box-toggle`.
- Read comments near pins and workarounds before changing them. They record why, usually a verified breakage.

## Maintenance and secrets

- After `just update`, run `just format`, `just check`, and `just build`. Pushing `flake.lock` (only when asked) is what makes CI rebuild and upload the source-built packages to Attic.
- The kimi-code VS Code extension in `home/editors/vscode.nix` is pinned by hash. On a fixed-output hash mismatch, `just rebuild-switch` / `just rebuild-switch-fast` (`scripts/rebuild.sh`) automatically run `scripts/fix-hashes.py --from-log` to update local fixed-output hashes and retry switching (still skipping upstream/nixpkgs hashes; disable with `AUTO_FIX_HASHES=0`). You can also invoke `just fix-hashes` directly.
- Edit MCP servers in `home/ai/mcp.nix` (`programs.mcp.servers`). Activation merges them into each tool's config, so don't hand-edit `~/.codex/config.toml` or `~/.kimi-code/mcp.json`.
- Never put tokens or subscription URLs in Nix files; they end up in the world-readable store. sing-box subscriptions live in `/var/lib/sing-box-config/subscriptions.yaml`. The Obsidian API key is read at activation.

## Conventions

- Comments and docs are mostly Chinese. Match the language of the surrounding file.
- Commit subjects usually follow `type(scope): summary`, e.g. `fix(ci): ...`, often with Chinese summaries. Match `git log`.
