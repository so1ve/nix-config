{
  ray.features = {
    "software/qq".home =
      {
        inputs,
        lib,
        pkgs,
        ...
      }:
      let
        qqFix = inputs.qq-fix.packages.${pkgs.stdenv.hostPlatform.system}.default;
        qqFixed = pkgs.symlinkJoin {
          name = "qq-fixed";
          paths = [ pkgs.qq ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            rm "$out/bin/qq" "$out/share/applications/qq.desktop"
            makeWrapper "${lib.getExe qqFix}" "$out/bin/qq" \
              --add-flags "${pkgs.qq}/bin/qq"
            substitute "${pkgs.qq}/share/applications/qq.desktop" \
              "$out/share/applications/qq.desktop" \
              --replace-fail "${pkgs.qq}/bin/qq" "$out/bin/qq"
          '';
          meta = pkgs.qq.meta // {
            mainProgram = "qq";
          };
        };
      in
      {
        home.packages = [ qqFixed ];
      };

    # fucking QQ fix
    "software/xwayclip" = {
      requires = [ "desktop/niri" ];
      home =
        { inputs, ... }:
        {
          imports = [ inputs.xwayclip.homeManagerModules.default ];

          services.xwayclip.enable = true;
        };
    };

    "software/telegram-web" = {
      requires = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://web.telegram.org/k/";
            custom_name = "Telegram Web";
          }
        ];
      };
    };

    "software/cinny" = {
      requires = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://app.cinny.in/";
            custom_name = "Cinny";
          }
        ];
      };
    };

    "software/discord" = {
      requires = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://discord.com/app";
            custom_name = "Discord";
          }
        ];
      };
    };

    "software/oopz" = {
      requires = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://web.oopz.cn/";
            custom_name = "Oopz";
          }
        ];
      };
    };

    "software/rust-zulip" = {
      requires = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://rust-lang.zulipchat.com/";
            custom_name = "Rust Zulip";
          }
        ];
      };
    };
  };
}
