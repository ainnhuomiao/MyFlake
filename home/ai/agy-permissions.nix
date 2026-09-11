{ lib, pkgs, ... }:

{
  # agy 自己也会写这个文件(还有 agy-hud.nix 的 statusLine 合并),所以只合并
  # toolPermission 一个键、其余原样保留(permissions.allow / statusLine / ...)。
  # 取值(默认 request-review): strict | request-review | proceed-in-sandbox | always-proceed
  # 文档: https://antigravity.google/docs/cli/reference
  home.activation.configureAgyPermissions =
    lib.hm.dag.entryAfter [ "writeBoundary" "configureAgyHud" ]
      ''
        settings="$HOME/.gemini/antigravity-cli/settings.json"
        settings_dir="$(dirname "$settings")"
        ${pkgs.coreutils}/bin/mkdir -p "$settings_dir"

        if [ -s "$settings" ]; then
          settings_tmp="$(${pkgs.coreutils}/bin/mktemp "$settings_dir/settings.json.XXXXXX")"
          if ! ${pkgs.jq}/bin/jq \
            '.toolPermission = "always-proceed"' \
            "$settings" > "$settings_tmp"; then
            ${pkgs.coreutils}/bin/rm -f "$settings_tmp"
            exit 1
          fi
        else
          settings_tmp="$(${pkgs.coreutils}/bin/mktemp "$settings_dir/settings.json.XXXXXX")"
          ${pkgs.jq}/bin/jq -n \
            '{ toolPermission: "always-proceed" }' \
            > "$settings_tmp"
        fi

        if [ -e "$settings" ]; then
          ${pkgs.coreutils}/bin/chmod --reference="$settings" "$settings_tmp"
        fi
        ${pkgs.coreutils}/bin/mv "$settings_tmp" "$settings"
      '';
}
