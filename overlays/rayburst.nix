# rayburst(原 motrix-next,上游已改名): 只修 NixOS 侧的动态链接问题,不再钉版本。
# 历史: 曾钉 3.9.6 的 version/src(并自算 cargoDeps/pnpmDeps);nixpkgs 升到 3.9.8
# 后带上 fix-copy-path.patch(目标 scripts/build-native-messaging-launcher.mjs),
# 钉回的旧 src 里没有该文件 → patchPhase 失败(2026-09-12 CI 红 + 本地 rebuild 卡住)。
# 现在跟随 nixpkgs 版本,只保留 autoPatchelf 补丁修复。
# 已实测(2026-10-16, cache.nixos.org 的 4.0.1 二进制): sidecar bin/aria2-next
# 仍动态链接(libstdc++.so.6 无 RPATH 解析,ldd 报 not found),autoPatchelf 不可省。
final: prev:

{
  rayburst = prev.rayburst.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.autoPatchelfHook ];

    buildInputs = (old.buildInputs or [ ]) ++ [
      prev.stdenv.cc.cc.lib # libgcc_s / libstdc++
      prev.zlib
    ];

    # pnpm build 的 Node.js 在小内存机器（如 1.9G VPS）上 V8 堆默认仅 ~1G，会 OOM。
    env = (old.env or { }) // {
      NODE_OPTIONS = "--max-old-space-size=4096";
    };

    # sidecar(aria2c fork) 是通用 linux ELF，需要指向 nixpkgs 的 ld-linux 与 glibc。
    # autoPatchelfHook 会在 fixupPhase 自动扫描 $out 下的 ELF 并修好。
    dontAutoPatchelf = false;
  });
}
