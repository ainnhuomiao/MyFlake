{ appearance }:
let
  c = appearance.catppuccin;
  h = appearance.toHex;
in
{
  completion = {
    border = {
      fg = (h c.blue);
    };
  };
  confirm = {
    border = {
      fg = (h c.blue);
    };
    btn_labels = [
      "  [Y]es  "
      "  (N)o  "
    ];
    btn_no = { };
    btn_yes = {
      reversed = true;
    };
    title = {
      fg = (h c.blue);
    };
  };
  filetype = {
    rules = [
      {
        fg = (h c.yellow);
        mime = "image/*";
      }
      {
        fg = (h c.mauve);
        mime = "{audio,video}/*";
      }
      {
        fg = (h c.red);
        mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
      }
      {
        fg = (h c.blue);
        mime = "application/{pdf,doc,rtf}";
      }
      {
        bg = (h c.red);
        is = "orphan";
        url = "*";
      }
      {
        fg = (h c.green);
        is = "exec";
        url = "*";
      }
      {
        bg = (h c.red);
        is = "dummy";
        url = "*";
      }
      {
        bg = (h c.red);
        is = "dummy";
        url = "*/";
      }
      {
        fg = (h c.blue);
        url = "*/";
      }
    ];
  };
  flavor = {
    dark = "";
    light = "";
  };
  help = {
    footer = {
      bg = (h c.text);
      fg = (h c.surface0);
    };
    on = {
      fg = (h c.blue);
    };
    run = {
      fg = (h c.mauve);
    };
  };
  input = {
    border = {
      fg = (h c.blue);
    };
    selected = {
      reversed = true;
    };
  };
  mgr = {
    border_style = {
      fg = (h c.overlay0);
    };
    border_symbol = "│";
    count_copied = {
      bg = (h c.green);
      fg = (h c.base);
    };
    count_cut = {
      bg = (h c.red);
      fg = (h c.base);
    };
    count_selected = {
      bg = (h c.yellow);
      fg = (h c.base);
    };
    cwd = {
      fg = (h c.blue);
    };
    find_keyword = {
      bold = true;
      fg = (h c.yellow);
      italic = true;
      underline = true;
    };
    find_position = {
      bg = "reset";
      bold = true;
      fg = (h c.mauve);
      italic = true;
    };
    hovered = {
      reversed = true;
    };
    marker_copied = {
      bg = (h c.green);
      fg = (h c.green);
    };
    marker_cut = {
      bg = (h c.red);
      fg = (h c.red);
    };
    marker_marked = {
      bg = (h c.blue);
      fg = (h c.blue);
    };
    marker_selected = {
      bg = (h c.yellow);
      fg = (h c.yellow);
    };
    preview_hovered = {
      underline = true;
    };
    syntect_theme = "";
    tab_active = {
      reversed = true;
    };
    tab_width = 1;
  };
  mode = {
    normal_alt = {
      bg = (h c.surface0);
      fg = (h c.blue);
    };
    normal_main = {
      bg = (h c.blue);
      fg = (h c.base);
      bold = true;
    };
    select_alt = {
      bg = (h c.surface0);
      fg = (h c.red);
    };
    select_main = {
      bg = (h c.red);
      fg = (h c.base);
      bold = true;
    };
    unset_alt = {
      bg = (h c.surface0);
      fg = (h c.red);
    };
    unset_main = {
      bg = (h c.red);
      fg = (h c.base);
      bold = true;
    };
  };
  notify = {
    icon_error = "";
    icon_info = "";
    icon_warn = "";
    title_error = {
      fg = (h c.red);
    };
    title_info = {
      fg = (h c.green);
    };
    title_warn = {
      fg = (h c.yellow);
    };
  };
  pick = {
    active = {
      bold = true;
      fg = (h c.mauve);
    };
    border = {
      fg = (h c.blue);
    };
  };
  status = {
    perm_exec = {
      fg = (h c.blue);
    };
    perm_read = {
      fg = (h c.yellow);
    };
    perm_sep = {
      fg = (h c.surface0);
    };
    perm_type = {
      fg = (h c.green);
    };
    perm_write = {
      fg = (h c.red);
    };
    progress_error = {
      bg = (h c.base);
      fg = (h c.red);
    };
    progress_label = {
      bold = true;
    };
    progress_normal = {
      bg = (h c.base);
      fg = (h c.blue);
    };
    separator_close = "";
    separator_open = "";
  };
  tasks = {
    border = {
      fg = (h c.blue);
    };
    hovered = {
      fg = (h c.mauve);
      underline = true;
    };
  };
  which = {
    cand = {
      fg = (h c.blue);
    };
    cols = 3;
    desc = {
      fg = (h c.mauve);
    };
    mask = {
      bg = (h c.base);
    };
    rest = {
      fg = (h c.surface0);
    };
    separator = "  ";
    separator_style = {
      fg = (h c.surface0);
    };
  };
}
