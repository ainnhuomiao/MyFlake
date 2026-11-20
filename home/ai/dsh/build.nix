# DSH(DeepSeek Harness)profile 的声明式构建助手。
#
# 设计依据(源码 profile-boot / app-boot 已核实):
# - profile 目录是 $DSH_HOME/profiles/<name>,里面 package.json 的
#   dsh.profile.bundles 先按 dsh 安装目录解析,再按 profile 的 node_modules 解析;
# - 单个插件由 cordis.patch.yml 的 `insert` 追加,`name` 是模块标识符,
#   `id` 只是条目句柄,两者可以不同;
# - 每次启动都会重写 profile 的 cordis.yml,所以整个 profile 目录不能进 store,
#   只有 node_modules 可以做成符号链接。
#
# 因此这里只产出两样东西:$out/node_modules(符号链接农场)和静态的
# $out/cordis.patch.yml、$out/package.json,由同目录的 module.nix 在激活时落到
# 真实目录里。
{ pkgs }:
let
  inherit (pkgs) lib;

  sanitize = lib.strings.sanitizeDerivationName;

  # id 是 patch 条目句柄,specifier 是 node_modules 里的包名,缺省相同。
  normalizePlugin = plugin: plugin // { specifier = plugin.specifier or plugin.id; };

  # 一个 insert 条目:name 写模块标识符,config 可选。
  pluginEntry =
    plugin:
    {
      inherit (plugin) id;
      name = plugin.specifier;
    }
    // lib.optionalAttrs (plugin ? config) { inherit (plugin) config; };

  # patch 层的值。overrides 先应用,disables 次之,plugins 最后统一追加。
  mkPatch =
    {
      plugins ? [ ],
      overrides ? { },
      disables ? [ ],
    }:
    lib.mapAttrsToList (id: attrs: { inherit id; } // attrs) overrides
    ++ map (id: {
      inherit id;
      disabled = true;
    }) disables
    ++ lib.optional (plugins != [ ]) {
      insert = map pluginEntry (map normalizePlugin plugins);
    };
in
{
  inherit mkPatch;

  # 自写或无外部依赖的插件:把源码目录整体拷进 store 即可。
  # 产物自身就是一个合法的包目录(package.json + 入口文件)。
  mkPlugin =
    {
      name,
      src,
    }:
    pkgs.runCommand "dsh-plugin-${sanitize name}" { } ''
      mkdir -p $out
      cp -a ${src}/. $out/
      chmod -R u+w $out
    '';

  # 带 npm 依赖的第三方插件。buildNpmPackage 产出的包目录自带 node_modules,
  # 正好满足"每个包自己解析依赖"的约定。
  # npmDepsHash 用 nix build 报错里给出的假哈希换出来即可。
  mkNpmPlugin =
    args:
    pkgs.buildNpmPackage (
      args
      // {
        dontNpmBuild = args.dontNpmBuild or true;
        installPhase =
          args.installPhase or ''
            runHook preInstall
            mkdir -p $out
            cp -a . $out/
            chmod -R u+w $out
            runHook postInstall
          '';
      }
    );

  # 组装一个 profile 的静态部分。
  #   bundles   —— 写进 package.json 的 dsh.profile.bundles(基础层,必须有)
  #   plugins   —— [{ id, package, specifier ?, config ? }],追加到 patch 层
  #   overrides —— { "<id>" = { config = ...; }; } 改已有行
  #   disables  —— [ "<id>" ],等价于 overrides 里的 disabled = true
  mkProfile =
    {
      name,
      bundles,
      plugins ? [ ],
      overrides ? { },
      disables ? [ ],
    }:
    let
      manifest = (pkgs.formats.json { }).generate "package.json" {
        name = "dsh-profile-${sanitize name}";
        private = true;
        dependencies = { };
        dsh.profile.bundles = bundles;
      };
      patch = (pkgs.formats.yaml { }).generate "cordis.patch.yml" (mkPatch {
        inherit plugins overrides disables;
      });
    in
    pkgs.runCommand "dsh-profile-${sanitize name}" { } ''
      mkdir -p $out/node_modules
      ${lib.concatMapStringsSep "\n" (plugin: ''
        install -d "$out/node_modules/$(dirname "${plugin.specifier}")"
        ln -s ${plugin.package} "$out/node_modules/${plugin.specifier}"
      '') (map normalizePlugin plugins)}
      install -m644 ${manifest} $out/package.json
      install -m644 ${patch} $out/cordis.patch.yml
    '';

  # 带完整依赖树的第三方 bundle(例如 @deepseek-harness-tui/dsh-tui,95 个包):
  # 依赖交给 pnpm 离线安装,产物是整个 node_modules 目录,再整目录链接进 profile。
  # dir 里必须放 package.json 和 pnpm-lock.yaml——它们是依赖与
  # dsh.profile.bundles 的单一事实源;pnpmDepsHash 用假哈希报错换出来。
  # 接线(overrides/disables/plugins)仍然由 Nix 生成,与 mkProfile 同构。
  mkPnpmProfile =
    {
      name,
      dir,
      pnpmDepsHash,
      plugins ? [ ],
      overrides ? { },
      disables ? [ ],
    }:
    let
      pname = "dsh-profile-${sanitize name}";
      patch = (pkgs.formats.yaml { }).generate "cordis.patch.yml" (mkPatch {
        inherit plugins overrides disables;
      });
    in
    pkgs.stdenv.mkDerivation {
      inherit pname;
      version = "0";
      src = dir;
      nativeBuildInputs = [
        pkgs.pnpmConfigHook
        pkgs.pnpm
      ];
      pnpmDeps = pkgs.fetchPnpmDeps {
        inherit pname;
        version = "0";
        src = dir;
        hash = pnpmDepsHash;
        fetcherVersion = 5;
      };
      # pnpmConfigHook 已经用 pnpmDeps 里的 store 跑完 pnpm install 了,
      # 这里不能再装一遍:二次安装会重新解析依赖图,离线状态下会报
      # ERR_PNPM_NO_OFFLINE_TARBALL。
      buildPhase = ''
        runHook preBuild
        test -d node_modules || {
          echo "pnpmConfigHook did not produce node_modules" >&2
          exit 1
        }
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -a node_modules $out/node_modules
        install -m644 package.json $out/package.json
        install -m644 ${patch} $out/cordis.patch.yml
        runHook postInstall
      '';
    };
}
