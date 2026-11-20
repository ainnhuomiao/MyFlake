# DSH 的 profile 声明式管理。
#
# 开启某个 profile 后,激活脚本会完全接管 $HOME/.dsh/profiles/<name>:
#   - node_modules 换成指向 store 的符号链接
#   - cordis.patch.yml 和 package.json 由 Nix 生成并覆盖
# 代价是 `dsh plugin`(本质是在 profile 目录里跑 pnpm)会失效,所以
# 声明式接管时通常要同时把 plugin-manager 两行 disable 掉:
#   disables = [ "plugin-manager" "tool-plugin-manager" ];
#
# 默认不接管任何 profile,保持现有 pnpm 工作流不变。
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  dsh = import ./build.nix { inherit pkgs; };

  profileModule =
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否由 Nix 接管 ${name} 这个 profile。";
        };
        bundles = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [
            "@deepseek-ai/dsh-base"
            "@deepseek-ai/dsh-web-app"
          ];
          description = "写进 package.json 的 dsh.profile.bundles,即基础 patch 层(pnpm 模式下忽略)。";
        };
        plugins = mkOption {
          type = types.listOf types.unspecified;
          default = [ ];
          example = lib.literalExpression ''
            [
              {
                id = "my-plugin";
                package = dsh.mkPlugin { name = "my-plugin"; src = ./plugins/my-plugin; };
              }
            ]
          '';
          description = "追加到 patch 层的插件:[{ id, package, specifier ?, config ? }]。";
        };
        overrides = mkOption {
          type = types.attrsOf types.unspecified;
          default = { };
          example = {
            agent-default-model.config = {
              provider = "deepseek-official";
              model = "deepseek-flash";
            };
          };
          description = "按 id 覆盖已有条目的字段(config 是整块替换,不深合并)。";
        };
        disables = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [
            "plugin-manager"
            "tool-plugin-manager"
          ];
          description = "按 id 关闭条目,等价于 overrides 里写 disabled = true。";
        };
        pnpm = mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                dir = mkOption {
                  type = types.path;
                  description = "含 package.json 与 pnpm-lock.yaml 的目录,是依赖与 bundles 的单一事实源。";
                };
                pnpmDepsHash = mkOption {
                  type = types.str;
                  example = "sha256-8Wj6aDsd8WCWTuN/K6nol6IXxbRLWIuWnH52Q9Ci+bQ=";
                  description = "pnpm 依赖的固定输出哈希;先用假哈希构建,从报错里取。";
                };
              };
            }
          );
          default = null;
          description = "非 null 时改用 pnpm 安装完整依赖树,适用于自带 bundle 的重型插件。";
        };
      };
    };

  # 激活脚本:profile 目录必须留在磁盘上(dsh 每次启动都会重写 cordis.yml)。
  # node_modules 必须是真实目录:做成指向 store 的符号链接时,深层 .pnpm 的
  # 模块解析会走偏(ERR_MODULE_NOT_FOUND),实测拷贝成实体目录才正常。
  # /nix/store 和 /home 都在 btrfs 上,reflink 拷贝近乎零成本。
  installScript =
    name: out:
    let
      dir = "$HOME/.dsh/profiles/${name}";
    in
    ''
      # ${name}
      mkdir -p "${dir}"
      # 首次接管时把 pnpm 生成的 patch 层留一份,方便回退或对照。
      if [ -e "${dir}/cordis.patch.yml" ] && [ ! -e "${dir}/cordis.patch.yml.pre-nix" ]; then
        cp -p "${dir}/cordis.patch.yml" "${dir}/cordis.patch.yml.pre-nix"
      fi
      rm -rf "${dir}/node_modules"
      cp -a --reflink=auto --no-preserve=mode ${out}/node_modules "${dir}/node_modules"
      install -m644 ${out}/cordis.patch.yml "${dir}/cordis.patch.yml"
      install -m644 ${out}/package.json "${dir}/package.json"
    '';
in
{
  options.programs.dsh.profiles = mkOption {
    type = types.attrsOf (types.submodule profileModule);
    default = { };
    description = ''
      由 Nix 接管的 DSH profile。键名就是 `dsh --profile <name>` 里的名字;
      未列出的 profile 保持 pnpm 管理,不受影响。
    '';
  };

  config =
    let
      enabled = lib.filterAttrs (_: profile: profile.enable) config.programs.dsh.profiles;
      built = lib.mapAttrs (
        name: profile:
        if profile.pnpm != null then
          dsh.mkPnpmProfile {
            inherit name;
            inherit (profile.pnpm) dir pnpmDepsHash;
            inherit (profile)
              plugins
              overrides
              disables
              ;
          }
        else
          dsh.mkProfile {
            inherit name;
            inherit (profile)
              bundles
              plugins
              overrides
              disables
              ;
          }
      ) enabled;
    in
    lib.mkIf (enabled != { }) {
      assertions = lib.mapAttrsToList (name: profile: {
        assertion = profile.pnpm != null || profile.bundles != [ ];
        message = "programs.dsh.profiles.${name}: 非 pnpm 模式必须给 bundles(至少包含 @deepseek-ai/dsh-base)。";
      }) enabled;

      home.activation.dshProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatStringsSep "\n" (lib.mapAttrsToList installScript built)
      );
    };
}
