{ pkgs, ... }:
{
  # ncro 模块用 mkDefault 指向未带 sqlite 的上游包。普通优先级换成补了 sqlite.dev 的包装。
  services.ncro.package = pkgs.ncro;
}
