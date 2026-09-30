{ appearance }:
let
  c = appearance.catppuccin;
  h = appearance.toHex;
in
''
  # vim: ft=dosini
  [Metadata]
  Name=Catppuccin ${appearance.catppuccinName}
  Version=0.1
  Author=MiraculousMoon
  Description=Catppuccin ${appearance.catppuccinName} Color Theme
  ScaleWithDPI=True

  [InputPanel]
  # 字体
  Font=Sans 13
  # 非选中候选字颜色
  NormalColor=${h c.text}
  # 选中候选字颜色
  HighlightCandidateColor=${h c.base}
  # 高亮前景颜色(输入字符颜色)
  HighlightColor=${h c.mauve}
  # 输入字符背景颜色
  HighlightBackgroundColor=${h c.surface1}
  #
  Spacing=3

  [InputPanel/TextMargin]
  # 候选字对左边距
  Left=10
  # 候选字对右边距
  Right=10
  # 候选字向上边距
  Top=6
  # 候选字向下边距
  Bottom=6

  [InputPanel/Background]
  Color=${h c.base}

  [InputPanel/Background/Margin]
  Left=2
  Right=2
  Top=2
  Bottom=2

  [InputPanel/Highlight]
  Color=${h c.mauve}

  [InputPanel/Highlight/Margin]
  # 高亮区域左边距
  Left=10
  # 高亮区域右边距
  Right=10
  # 高亮区域上边距
  Top=7
  # 高亮区域下边距
  Bottom=7

  [Menu]
  Font=Sans 10
  NormalColor=${h c.text}
  HighlightColor=${h c.base}
  Spacing=3

  [Menu/Background]
  Color=${h c.base}

  [Menu/Background/Margin]
  Left=2
  Right=2
  Top=2
  Bottom=2

  [Menu/ContentMargin]
  Left=2
  Right=2
  Top=2
  Bottom=2

  [Menu/Highlight]
  Color=${h c.mauve}

  [Menu/Highlight/Margin]
  Left=10
  Right=10
  Top=5
  Bottom=5

  [Menu/Separator]
  Color=${h c.surface1}

  [Menu/CheckBox]
  Image="${./radio.png}"

  [Menu/SubMenu]
  Image="${./arrow.png}"

  [Menu/TextMargin]
  Left=5
  Right=5
  Top=5
  Bottom=5
''
