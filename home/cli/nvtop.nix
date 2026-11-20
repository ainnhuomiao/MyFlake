{
  pkgs,
  ...
}:
let
  # nixpkgs d5b6068 缺陷: allowBroken=true 时 cuda_compat 的 meta.available 被翻转,
  # 导致 cuda_nvml_dev 拉入 autoAddCudaCompatRunpath → cuda_compat (12.9 仅有 L4T/aarch64 发布, x86_64 src=null, 构建必失败)。
  # 修复: 在 cudaPackages scope 内强制 enableHook=false (x86_64 上该 hook 本就是空操作)。
  cudaPackages = pkgs.cudaPackages.overrideScope (
    final: prev: {
      autoAddCudaCompatRunpath = prev.autoAddCudaCompatRunpath.overrideAttrs (o: {
        passthru = o.passthru // {
          enableHook = false;
        };
      });
    }
  );
in
{
  home.packages = [
    (pkgs.nvtopPackages.full.override {
      inherit cudaPackages;
    })
  ];
}
