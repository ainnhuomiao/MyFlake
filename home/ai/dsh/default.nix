# DSH(DeepSeek Harness)相关的全部配置都收在这个目录里:
#   module.nix —— profile 管理的选项与激活脚本(对外只暴露 programs.dsh.*)
#   build.nix  —— 构建助手:mkPlugin / mkProfile / mkPnpmProfile
#   tui.nix    —— dsh-tui profile 实例
#   tui/       —— 该 profile 的 package.json 与 pnpm-lock.yaml
{
  imports = [
    ./module.nix
    ./tui.nix
  ];
}
