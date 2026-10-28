# AGENTS.md

Personal NixOS flake for one machine: host `nixos`, user `huomiao`, `x86_64-linux` only, built with flake-parts. This working copy is that live host, so switching affects it immediately.

`README.md` is a Chinese user manual and is partly stale. For example, it pins Noctalia to v5.0.1 (`flake.nix` uses v5.2.1), and it documents `nix build .#omp-provider`, `.#omp`, and `.#pi`, which are not flake outputs. Trust `nix flake show` and the code.

## Commands

Run from the repo root. Typical loop: edit, `git add` new files, `just format`, `just check`.

- `just format`: `nix fmt` (treefmt: nixfmt, prettier for Markdown/YAML/JSON, shfmt, stylua). Rewrites files in place across the repo.
- `just check`: `nix flake check --fallback`. Evaluates every output, including the NixOS config, and builds the `treefmt` and `disko-layouts` checks. It does not build `packages`.
- `just build`: builds the `nixos` system without activating it. CI never builds the system closure, so this is the only full system check.
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

- `just rebuild-switch` is allowed only after `just check` passes. It activates this machine immediately, because sudo is passwordless (`system/core/security.nix`).

## Gotchas

- Flakes see only git-tracked files. A new file that isn't `git add`ed (or at least `git add -N`) makes evaluation fail with a missing-path error.
- `just format` rewrites any unformatted file in the repo, including unrelated WIP. Check `git status` and `git diff` afterwards.

## Architecture

- `flake.nix` declares inputs and `nixConfig`. Outputs come from `flake/modules/` (packages, checks, dev shells, formatter, overlays) and `hosts/`.
- `hosts/default.nix` builds `nixosConfigurations.nixos` from `hosts/nixos/`, `system/`, disko, ncro, and Home Manager profile `home/profiles/huomiao@nixos`.
- `system/` holds NixOS modules and `home/` holds Home Manager modules. `home/programs/default.nix` aggregates per-program modules. Plain packages go in `home/programs/apps.nix`.
- `me` (`me.nix`) and `appearance` (`lib/appearance.nix`) are specialArgs in all modules. Use them instead of importing `me.nix` or hardcoding colors and fonts.
- `pkgs/` holds local packages (overlay in `pkgs/default.nix`). `overlays/` holds nixpkgs patches. `flake/modules/overlays.nix` combines both.
- Flake outputs use their own nixpkgs instance (`flake/modules/packages.nix`) with only `pkgs/` and `overlays/`. It has no rust-overlay; NixOS adds that in `system/nix/nixpkgs.nix`. The nixpkgs `config` is duplicated in `flake/modules/packages.nix` and `system/nix/nixpkgs.nix`, so keep them in sync.

## Deliberate choices, don't "clean up"

- Input wiring is deliberate, and comments in `flake.nix` say why. `noctalia` follows host nixpkgs because a bundled older glibc crashes at startup. `emanote`, `herdr`, and `llm-agents` keep their own nixpkgs pins.
- Bumping `noctalia` also means bumping `officialPlugins.rev` in `home/programs/noctalia/default.nix` and reviewing `patches/noctalia-transparent-bar-capsule-blur.patch`, which limits blur on transparent bars to their capsules and makes media fallback content inherit capsule foreground colors.
- `packages` outputs are deliberately limited to the CI-prebuilt set plus `disko`. Vendor apps belong in `home/` or overlays. `nix flake check` doesn't build `packages`; CI builds the explicit package list in `.github/workflows/nix.yml`.
- To get a source-built package into the Attic cache, add it to `flake/modules/packages.nix` and to the build list in `.github/workflows/nix.yml`.
- sing-box is not started at boot (`system/proxy/default.nix`, `wantedBy = []`). Manage it with `sing-box-toggle`.
- Read comments near pins and workarounds before changing them. They record why, usually a verified breakage.

## Maintenance and secrets

- After `just update`, run `just format`, `just check`, and `just build`. Pushing `flake.lock` (only when asked) is what makes CI rebuild and upload the source-built packages to Attic.
- The kimi-code VS Code extension in `home/editors/vscode.nix` is pinned by hash. On a fixed-output hash mismatch, update that hash.
- Edit MCP servers in `home/ai/mcp.nix` (`programs.mcp.servers`). Activation merges them into each tool's config, so don't hand-edit `~/.codex/config.toml` or `~/.kimi-code/mcp.json`.
- Never put tokens or subscription URLs in Nix files; they end up in the world-readable store. sing-box subscriptions live in `/var/lib/sing-box-config/subscriptions.yaml`. The Obsidian API key is read at activation.

## Conventions

- Comments and docs are mostly Chinese. Match the language of the surrounding file.
- Commit subjects usually follow `type(scope): summary`, e.g. `fix(ci): ...`, often with Chinese summaries. Match `git log`.
