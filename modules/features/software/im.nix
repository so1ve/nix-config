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
        pkgs,
        ...
      }:
      mkChromiumPwa {
        inherit config pkgs;
        name = "telegram-web";
        desktopName = "Telegram Web";
        description = "Telegram Web K";
        url = "https://web.telegram.org/k/";
        icon = pkgs.fetchurl {
          url = "https://web.telegram.org/k/assets/img/android-chrome-512x512.png?v=jw3mK7G9Ry";
          hash = "sha256-e1BW46Z7+K9yIftBUDVaDIN8Du9NfWinVAp7SHnp1ko=";
        };
      };

    "software/cinny".home =
      {
        config,
        mkChromiumPwa,
        pkgs,
        ...
      }:
      mkChromiumPwa {
        inherit config pkgs;
        name = "cinny";
        desktopName = "Cinny";
        description = "Matrix client";
        url = "https://app.cinny.in/";
        icon = pkgs.fetchurl {
          url = "https://app.cinny.in/public/android/android-chrome-512x512.png";
          hash = "sha256-4O1XGmsSqjPmGVtvSiRD3AquvUDK/7Y6aLt5iKV84hg=";
        };
      };
  };
}
