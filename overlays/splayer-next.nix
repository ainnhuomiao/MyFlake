# splayer-next 1.1.0 的 Rust 侧是 aws-lc-sys 0.43（aws-lc-rs 1.17）。
# nixos-unstable-small 41691813（2026-11-09）起，cargoSetupHook 的
# cargoUseSystemLibs（nixpkgs #537108）在 preConfigure 导出
# AWS_LC_SYS_USE_SYSTEM=1。该版本找不到系统 AWS-LC 时直接 panic，不再回退源码。
# 包装的 buildInputs 只有 openssl。OPENSSL_DIR 并未设置，探测落到 pkg-config：
# openssl 与 libcrypto 两个模块都指向 openssl-dev，而它没有 openssl/base.h。
# 把 aws-lc 追加在 openssl 之后，openssl 的 .pc 仍优先，aws-lc 模块可以被找到
# （这一版 nixpkgs 的 aws-lc 提供 aws-lc / libcrypto-awslc，不占用 openssl.pc）。
# 上游把 aws-lc 加进 buildInputs 后删除本文件。
final: prev:

{
  splayer-next = prev.splayer-next.overrideAttrs (old: {
    buildInputs =
      let
        oldInputs = old.buildInputs or [ ];
      in
      if builtins.elem prev.aws-lc oldInputs then oldInputs else oldInputs ++ [ prev.aws-lc ];
  });
}
