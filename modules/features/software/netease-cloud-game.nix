{
  ray.features."software/netease-cloud-game" = {
    home =
      {
        config,
        lib,
        mkFirefoxPwaInstall,
        pkgs,
        ...
      }:
      mkFirefoxPwaInstall {
        inherit config lib pkgs;
        name = "netease-cloud-game";
        description = "Install NetEase Cloud Game as a Firefox PWA";
        manifestUrl = "https://cg.163.com/manifestindex.json";
        installArgs = [
          "--document-url"
          "https://cg.163.com/"
          "--start-url"
          "https://cg.163.com/"
          "--icon-url"
          "https://cg.163.com/logo2.png"
          "--name"
          "网易云游戏"
          "--description"
          "网易官方云游戏平台"
        ];
      };
  };
}
