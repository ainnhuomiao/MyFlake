final: prev:

{
  # MyFlake: 修 v2rayN Linux 的 TUN 门禁。上游 AllowEnableTun() 要求
  # LinuxSudoPwd 非空, 而该密码只在界面输入时写入内存、从不持久化 → 每次重启
  # v2rayN 后构造器把 EnableTun 重置为 off(sway 上系统代理脚本也不可用),
  # 表现为 rebuild 后所有节点 -1。本机 sudo 为 NOPASSWD 免密, 门禁无意义,
  # 打补丁让 Linux 分支直接放行(sudo -S 空密码在免密下可用, core 提权不受影响)。
  v2rayn = prev.v2rayn.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/v2rayn-tun-gate.patch ];
  });
}
