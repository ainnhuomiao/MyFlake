# AGENTS.md

Personal NixOS flake for one machine: host `nixos`, user `huomiao`, `x86_64-linux` only, built with flake-parts. This working copy is that live host, so switching affects it immediately.

`dms-niri` uses niri + Dank Material Shell (DMS); `main` retains labwc + Noctalia. `README.md` is a Chinese user manual and may contain stale examples. Trust `nix flake show` and the code.

## Commands

Run from the repo root. Typical loop: edit, `git add` new files, `just format`, `just check`.

- `just format`: `nix fmt` (treefmt: nixfmt, prettier for Markdown/YAML/JSON, shfmt, stylua). Rewrites files in place across the repo.
- `just check`: `nix flake check --fallback`. Evaluates every output, including the NixOS config, and builds the `treefmt`, `disko-layouts`, and `niri-config` checks. It does not build `packages`.
- `just build`: builds the `nixos` system without activating it. CI never builds the system closure, so this is the only full system check.
- Single check: `nix build --no-link .#checks.x86_64-linux.treefmt` (formatting) or `.#checks.x86_64-linux.disko-layouts` (pure eval of `lib/disko_layout/`).
- Single package: `nix build --no-link .#<name>` for names in `nix flake show`. Overlay-only packages such as `omp-provider` build via `.#nixosConfigurations.nixos.pkgs.omp-provider`.
- Eval one option without building: `nix eval .#nixosConfigurations.nixos.config.<path>`.
- There is no test suite. Verification is the checks above.
- `just build` can run for a long time because it builds the whole system closure. Use a long timeout or run it in the background.
- Substituter errors in `just check` output, such as an unreachable substituter, are logged and ignored because of `--fallback`. Trust the exit code.
- Run `just format` before `just check`. `just verify` and `just rebuild-switch` run check first, so unformatted files fail them.

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
- `hosts/default.nix` builds `nixosConfigurations.nixos` from `hosts/nixos/`, `system/`, disko, selector4nix, and Home Manager profile `home/profiles/huomiao@nixos`.
- `system/` holds NixOS modules and `home/` holds Home Manager modules. `home/programs/default.nix` aggregates per-program modules. Plain packages go in `home/programs/apps.nix`.
- `me` (`me.nix`) and `appearance` (`lib/appearance.nix`) are specialArgs in all modules. Use them instead of importing `me.nix` or hardcoding colors and fonts.
- `pkgs/` holds local packages (overlay in `pkgs/default.nix`). `overlays/` holds nixpkgs patches. `flake/modules/overlays.nix` combines both.
- Flake outputs use their own nixpkgs instance (`flake/modules/packages.nix`) with only `pkgs/` and `overlays/`. It has no rust-overlay; NixOS adds that in `system/nix/nixpkgs.nix`. The nixpkgs `config` is duplicated in `flake/modules/packages.nix` and `system/nix/nixpkgs.nix`, so keep them in sync.

## Deliberate choices, don't "clean up"

- Input wiring is deliberate, and comments in `flake.nix` say why. `emanote`, `herdr`, and `llm-agents` keep their own nixpkgs pins.
- niri and DMS use native nixpkgs modules/packages. niri KDL is managed in `home/wm/niri/config.nix`; do not run `dms setup` to overwrite it. Use the upstream niri keybinding template from the locked DMS package with Kitty as the terminal; do not port personal shortcuts from `main`. DMS settings/session JSON are seeded only on first activation so the UI can save changes. Video resources are preserved, but video wallpaper playback is not migrated yet.
- `packages` outputs are deliberately limited to the CI-prebuilt set plus `disko`. Vendor apps belong in `home/` or overlays. `nix flake check` doesn't build `packages`, so the comment in `flake/modules/packages.nix` that says it does is stale.
- To get a source-built package into the Attic cache, add it to `flake/modules/packages.nix` and to the build list in `.github/workflows/nix.yml`.
- dae and mihomo are not started at boot (`system/proxy.nix`, `wantedBy = []`). Manage them with `dae-toggle`.
- Read comments near pins and workarounds before changing them. They record why, usually a verified breakage.

## Maintenance and secrets

- After `just update`, run `just format`, `just check`, and `just build`. Pushing `flake.lock` (only when asked) is what makes CI rebuild and upload the source-built packages to Attic.
- The kimi-code VS Code extension in `home/editors/vscode.nix` is pinned by hash. On a fixed-output hash mismatch, update that hash.
- Edit MCP servers in `home/ai/mcp.nix` (`programs.mcp.servers`). Activation merges them into each tool's config, so don't hand-edit `~/.codex/config.toml` or `~/.kimi-code/mcp.json`.
- Never put tokens or subscription URLs in Nix files; they end up in the world-readable store. Mihomo subscriptions live in `/var/lib/mihomo-config/subscriptions.yaml`. The Obsidian API key is read at activation.

## Conventions

- Comments and docs are mostly Chinese. Match the language of the surrounding file.
- Commit subjects usually follow `type(scope): summary`, e.g. `fix(ci): ...`, often with Chinese summaries. Match `git log`.
