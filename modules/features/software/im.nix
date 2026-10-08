{
  ray.features = {
    "software/dingtalk".home =
      { inputs, pkgs, ... }:
      let
        dingtalk = (import inputs.so1ve { inherit pkgs; }).dingtalk;
      in
      {
        home.packages = [ dingtalk ];
      };

    "software/qq".nixos =
      { inputs, ... }:
      {
        imports = [ inputs.linuxqq-wayland-fix.nixosModules.default ];

        programs.linuxqq-wayland-fix.enable = true;
        environment.variables.QQ_CLIPBOARD_FIX_DISABLE = "1";
      };

    "software/xwayclip" = {
      requires.anyOf = [
        "desktop/hyprland"
        "desktop/niri"
      ];
      home =
        { inputs, ... }:
        {
          imports = [ inputs.xwayclip.homeManagerModules.default ];

          services.xwayclip.enable = true;
        };
    };

    "software/telegram-web" = {
      requires.allOf = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://web.telegram.org/k/";
            custom_name = "Telegram Web";
            appId = "nigookeodlehlnjcpdfifmophdcbjoma";
          }
        ];
      };
    };

    "software/cinny" = {
      requires.allOf = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://app.cinny.in/";
            custom_name = "Cinny";
            appId = "bcngdmpegpihnheapppgoniglphkpfhm";
          }
        ];
      };
    };

    "software/discord" = {
      requires.allOf = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://discord.com/app";
            custom_name = "Discord";
            appId = "pliiebkcmokkgndfalahlmimanmbjlab";
          }
        ];
      };
    };

    "software/oopz" = {
      requires.allOf = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://web.oopz.cn/";
            custom_name = "Oopz";
            appId = "hgbpnngkjfhcnkdakkemekcknmjdhfkc";
          }
        ];
      };
    };

    "software/rust-zulip" = {
      requires.allOf = [ "software/chrome" ];
      nixos = {
        ray.chromeWebApps = [
          {
            url = "https://rust-lang.zulipchat.com/";
            custom_name = "Rust Zulip";
            appId = "doaomjibpoemjdfcplalmkmdhgaadood";
          }
        ];
      };
    };
  };
}
