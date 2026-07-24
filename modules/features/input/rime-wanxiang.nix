{
  ray.features."input/rime-wanxiang" = {
    nixos =
      { pkgs, ... }:
      {
        ray.input.rime.dataPackages = [ pkgs.rime-wanxiang ];
      };

    home =
      {
        lib,
        pkgs,
        ...
      }:
      {
        ray.input.rime = {
          schemas = lib.mkBefore [ "wanxiang" ];
          suggestedDefaults = lib.mkBefore [ "wanxiang_suggested_default" ];
        };

        xdg.dataFile."fcitx5/rime/wanxiang-lts-zh-hans.gram".source = pkgs.fetchurl {
          url = "https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram";
          hash = "sha256-KAzOrsRfEOlqT9fUCSanjS2qQJyxrULK5NBe9/Ai7vM=";
        };
      };
  };
}
