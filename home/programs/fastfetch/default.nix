{ appearance, ... }:
let
  c = appearance.catppuccin;
  a = appearance.toAnsi;
in
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "kitty-direct";
        source = "${../../../assets/fastfetch-logo.png}";
        width = 32;
        padding = {
          right = 2;
        };
      };
      display = {
        separator = " ";
        key = {
          width = 15;
        };
        color = {
          keys = a c.mauve;
        };
        size = {
          binaryPrefix = "jedec";
        };

      };
      modules = [
        {
          type = "title";
          color = {
            user = a c.yellow;
            at = a c.mauve;
            host = a c.green;
          };
        }
        {
          type = "separator";
          string = "────────────────────────────────────────";
        }
        {
          type = "os";
          key = "󰣇 OS     ";
        }
        {
          type = "kernel";
          key = "󰌽 Kernel ";
        }
        {
          type = "uptime";
          key = "󰔟 Uptime ";
        }
        {
          type = "packages";
          key = "󰏖 PKGs   ";
        }
        {
          type = "shell";
          key = "󱆃 Shell  ";
        }
        {
          type = "display";
          key = "󰍹 Resolution";
        }
        {
          type = "de";
          key = "󰧨 DE     ";
        }
        {
          type = "wm";
          key = "󱂬 WM     ";
        }
        {
          type = "terminal";
          key = "󱊑 Terminal";
        }
        {
          type = "cpu";
          key = "󰻟 CPU    ";
          showPeCoreCount = true;
        }
        {
          type = "gpu";
          key = "󰢮 GPU    ";
        }
        {
          type = "memory";
          key = "󰍛 Memory ";
          format = "{used} / {total} ({percentage})";
        }
        {
          type = "disk";
          key = "󰋊 Disk   ";
          format = "{##${c.sapphire}}{mountpoint} ({filesystem}){#} │ {size-used} / {size-total} ({size-percentage})";
        }
        {
          type = "localip";
          key = "󰩟 Local IP";
          showIpv4 = true;
          showIpv6 = false;
        }
      ];
    };
  };
}
