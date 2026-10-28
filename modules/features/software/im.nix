{
  ray.features = {
    "software/dingtalk".home =
      _:
      { inputs, pkgs, ... }:
      let
        dingtalk = (import inputs.so1ve { inherit pkgs; }).dingtalk;
      in
      {
        home.packages = [ dingtalk ];
      };

    "software/qq".nixos =
      _:
      { inputs, ... }:
      {
        imports = [ inputs.linuxqq-wayland-fix.nixosModules.default ];

        programs.linuxqq-wayland-fix.enable = true;
      };

    "software/qq".home =
      _:
      { osConfig, ... }:
      {
        xdg.desktopEntries.qq = {
          name = "QQ";
          comment = "QQ";
          exec = "${osConfig.programs.linuxqq-wayland-fix.package}/bin/linuxqq-wayland-fix %U";
          icon = "qq";
          terminal = false;
          categories = [ "Network" ];
          settings.StartupWMClass = "QQ";
        };

        # Hide the upstream repair entry after replacing the default QQ entry.
        xdg.dataFile."applications/linuxqq-wayland-fix.desktop".text = ''
          [Desktop Entry]
          Hidden=true
        '';
      };

    "software/telegram-web" = {
      requires.allOf = [ "software/chrome" ];
      nixos = _: {
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
      nixos = _: {
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
      nixos = _: {
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
      nixos = _: {
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
      nixos = _: {
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
