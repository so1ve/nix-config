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

    "software/telegram-web".home =
      {
        config,
        mkChromiumPwa,
        mkIcon,
        pkgs,
        ...
      }:
      mkChromiumPwa {
        inherit config pkgs;
        name = "telegram-web";
        desktopName = "Telegram Web";
        description = "Telegram Web K";
        url = "https://web.telegram.org/k/";
        icon = mkIcon "telegram.png";
      };

    "software/cinny".home =
      {
        config,
        mkChromiumPwa,
        mkIcon,
        pkgs,
        ...
      }:
      mkChromiumPwa {
        inherit config pkgs;
        name = "cinny";
        desktopName = "Cinny";
        description = "Matrix client";
        url = "https://app.cinny.in/";
        icon = mkIcon "cinny.png";
      };

    "software/rust-zulip".home =
      {
        config,
        mkChromiumPwa,
        mkIcon,
        pkgs,
        ...
      }:
      mkChromiumPwa {
        inherit config pkgs;
        name = "rust-zulip";
        desktopName = "Rust Zulip";
        description = "Rust project Zulip";
        url = "https://rust-lang.zulipchat.com/";
        icon = mkIcon "zulip.svg";
      };
  };
}
