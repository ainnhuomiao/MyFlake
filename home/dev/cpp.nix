{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnumake
    meson
    ninja
    cmake
    gdb
    lldb
    clang-tools
    bear
  ];
}
