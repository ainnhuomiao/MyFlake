{ fetchurl, fcitx5-pinyin-zhwiki }:
# 收编说明: nixpkgs 已有此包(0.3.0, 含 web-slang/zhwiki/zhwikisource/zhwiktionary
# 4 部词典 + updateScript), 这里只在其上 override date 到上游 0.3.0 release 的
# 最新词典日期 20260416 并换成对应 hash。
fcitx5-pinyin-zhwiki.overrideAttrs (old: {
  date = "20260416";
  srcs = [
    (fetchurl {
      url = "https://github.com/felixonmars/fcitx5-pinyin-zhwiki/releases/download/${old.version}/web-slang-20260416.dict";
      hash = "sha256-RGbdsrorpXo9sAg9A49Ql1dG891mW9LMwDk5jrdCUC4=";
    })
    (fetchurl {
      url = "https://github.com/felixonmars/fcitx5-pinyin-zhwiki/releases/download/${old.version}/zhwiki-20260416.dict";
      hash = "sha256-m7b9A/A1DMEzQOw0/1n2lb336w8U22rPE8HryR+Jgjs=";
    })
    (fetchurl {
      url = "https://github.com/felixonmars/fcitx5-pinyin-zhwiki/releases/download/${old.version}/zhwikisource-20260416.dict";
      hash = "sha256-aJV1sarz0L/9eRdaMbOt79yq/m7HGUzzQrPTlqXlPyc=";
    })
    (fetchurl {
      url = "https://github.com/felixonmars/fcitx5-pinyin-zhwiki/releases/download/${old.version}/zhwiktionary-20260416.dict";
      hash = "sha256-eHdHaX3BEcPsPlxdxpNShPfkBxKtoD7LenHdM0e9aUQ=";
    })
  ];
})
