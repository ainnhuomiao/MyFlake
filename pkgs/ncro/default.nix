{
  ncro,
  sqlite,
}:
# 1) 上游 nix/package.nix 在 Linux 上用 clang --ld-path=wild 链接，buildInputs 却只有
#    openssl.dev。sqlx 0.9 的 sqlite 特性依赖 libsqlite3-sys 且未启用 bundled：
#    pkg-config 找不到 sqlite3 时只发出 -lsqlite3，wild 于是报
#    Couldn't find library sqlite3。sqlite.dev 带有 sqlite3.pc，并传播含 libsqlite3.so 的 out。
# 2) 修复 router 在“前置优先级组返回 404 + 后续上游（如 cache.nixos.org）网络错误或处于
#    cooldown”时误判 NotFound（跳过 fallback_cache 并污染 Nix 负缓存）的问题。
ncro.overrideAttrs (old: {
  buildInputs = (old.buildInputs or [ ]) ++ [ sqlite.dev ];
  patches = (old.patches or [ ]) ++ [ ./no-false-404-on-upstream-error.patch ];
})
