# cc-switch 3.16.5 的 rusqlite 开了 bundled，本来会自己编译 SQLite。
# nixos-unstable-small 的 cargoSetupHook（nixpkgs #537108）在 preConfigure
# 导出 LIBSQLITE3_SYS_USE_PKG_CONFIG=1。libsqlite3-sys 0.28 见到该变量就改走
# pkg-config，不再用 bundled。包装的 buildInputs 没有 sqlite，探测失败后只剩
# cargo:rustc-link-lib=dylib=sqlite3，ld 报 cannot find -lsqlite3。
# sqlite.dev 带有 sqlite3.pc，并传播含 libsqlite3.so 的 out。
# 上游已经把 sqlite 或 sqlite.dev 放进 buildInputs 后，这里不再追加。
final: prev:

{
  cc-switch = prev.cc-switch.overrideAttrs (old: {
    buildInputs =
      let
        oldInputs = old.buildInputs or [ ];
        hasSqlite = builtins.any (dep: dep == prev.sqlite || dep == prev.sqlite.dev) oldInputs;
      in
      if hasSqlite then oldInputs else oldInputs ++ [ prev.sqlite.dev ];

    # Nix 沙箱根目录对构建用户可写，/nonexistent/directory 能被 mkdir。
    # export_sql 因此返回 Ok，而测试期望失败；panic 还会 poison 同文件的
    # mutex，把 import_export_sync 里其余用例一并拖垮。这条与 sqlite 链接无关。
    # 跳过它之后，同文件其余 24 个测试以及 lib 的 1715 个测试都通过。
    checkFlags = (old.checkFlags or [ ]) ++ [
      "--skip=export_sql_returns_error_for_invalid_path"
    ];
  });
}
