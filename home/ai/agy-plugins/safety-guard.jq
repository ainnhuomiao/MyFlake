def cmd_prefix:
  "(^|[;&|()\\n]\\s*)([A-Za-z_][A-Za-z0-9_]*=\\S+\\s+)*(sudo(\\s+-[A-Za-z]+)*\\s+)?(rtk\\s+)?";

def check($cmd):
  if ($cmd | test(cmd_prefix + "rm\\s+([^;&|\\n]*\\s)?(-[A-Za-z]*[rR][A-Za-z]*|--recursive)\\b[^;&|\\n]*\\s(/\\*?(\\s|$|[;&|])|~(/\\*)?(\\s|$|[;&|])|\\$HOME(/\\*)?(\\s|$|[;&|])|\"\\$HOME(/\\*)?\")")) then
    "检测到针对根目录或家目录的递归删除 (rm -r)，请人工确认"
  elif ($cmd | test(cmd_prefix + "(mkfs(\\.[a-z0-9]+)?|wipefs|fdisk|parted|sgdisk)\\b")) then
    "检测到磁盘分区/格式化命令，请人工确认"
  elif ($cmd | test(cmd_prefix + "dd\\b[^;&|\\n]*\\bof=/dev/")) then
    "检测到直接写入块设备的 dd 命令，请人工确认"
  elif ($cmd | test(cmd_prefix + "git\\s+(-C\\s+\\S+\\s+)?push\\b[^;&|\\n]*(\\s|^)(--force\\b|--force-with-lease\\b|-f\\b)")) then
    "检测到 git 强制推送 (force push)，请人工确认"
  elif ($cmd | test(cmd_prefix + "git\\s+(-C\\s+\\S+\\s+)?reset\\b[^;&|\\n]*\\s--hard\\b")) then
    "检测到 git reset --hard（会丢弃未提交改动），请人工确认"
  elif ($cmd | test(cmd_prefix + "git\\s+(-C\\s+\\S+\\s+)?clean\\b[^;&|\\n]*\\s-[A-Za-z]*f")) then
    "检测到 git clean -f（会永久删除未跟踪文件），请人工确认"
  elif ($cmd | test(cmd_prefix + "just\\s+(disko|install|clean)\\b")) then
    "检测到 MyFlake 高风险 just 任务，请人工确认"
  elif ($cmd | test(cmd_prefix + "(nix-collect-garbage\\b[^;&|\\n]*(-d|--delete-old)|nh\\s+clean\\b)")) then
    "检测到不可逆 Nix 垃圾回收/清理旧代命令，请人工确认"
  else
    null
  end;

(.toolCall.args.CommandLine // "") as $cmd
| check($cmd) as $reason
| if $reason != null then
    { decision: "force_ask", reason: $reason }
  else
    { decision: "allow" }
  end
