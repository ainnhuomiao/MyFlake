{ workbuddy, python3 }:
# WorkBuddy 官方 deb 依赖魔改 Electron 的原生 API electron.workbuddyStorage 作为
# at-rest 凭据引导密钥源; workbuddy-nix 换成系统 electron 后该 API 缺失, 密钥不可用,
# 子会话(如增强提示)走 CBC 通道时报 "CBC credential bootstrap channel closed early"。
# 构建期把 main/index.js 的密钥源替换为独立持久密钥文件(见 credential-bootstrap-patch.py)。
workbuddy.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    ${python3}/bin/python3 ${./credential-bootstrap-patch.py} \
      "$out/opt/WorkBuddy/resources/app.asar.unpacked/main/index.js"
  '';
})
