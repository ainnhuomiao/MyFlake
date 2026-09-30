{ appearance }:
let
  c = appearance.catppuccin;
in
''
  # Catppuccin ${appearance.catppuccinName}
  set -l fg      ${c.text}
  set -l comment ${c.overlay0}
  set -l cyan    ${c.sky}
  set -l blue    ${c.blue}
  set -l purple  ${c.mauve}
  set -l green   ${c.teal}
  set -l red     ${c.red}
  set -l yellow  ${c.yellow}
  set -l fg_dim  ${c.subtext0}
  set -l sel_bg  ${c.surface0}

  # Syntax Highlighting
  set -g fish_color_normal         $fg
  set -g fish_color_command        $cyan
  set -g fish_color_keyword        $purple
  set -g fish_color_quote          $green
  set -g fish_color_param          $fg_dim
  set -g fish_color_redirection    $blue
  set -g fish_color_end            $comment
  set -g fish_color_comment        $comment
  set -g fish_color_error          $red
  set -g fish_color_escape         $cyan
  set -g fish_color_operator       $purple
  set -g fish_color_autosuggestion $comment
  set -g fish_color_cancel         $red

  # Selection
  set -g fish_color_selection    --background=$sel_bg
  set -g fish_color_search_match --background=$sel_bg

  # Completion Pager
  set -g fish_pager_color_progress            $comment
  set -g fish_pager_color_prefix              $purple
  set -g fish_pager_color_completion          $fg
  set -g fish_pager_color_description         $comment
  set -g fish_pager_color_selected_background --background=$sel_bg
''
