{
  ray.features = {
    "software/qq".home =
      { pkgs, ... }:
      {
        # FIXME: revert this after upstream fixes the Wayland issue
        home.packages = [
          (pkgs.qq.override {
            commandLineArgs = "--ozone-platform=wayland";
          })
        ];
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
