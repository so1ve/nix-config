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
        mkFirefoxPwaInstall,
        pkgs,
        ...
      }:
      mkFirefoxPwaInstall {
        inherit config pkgs;
        name = "telegram-web";
        description = "Install Telegram Web K";
        manifestUrl = "https://web.telegram.org/k/site.webmanifest";
      };

    "software/cinny".home =
      {
        config,
        mkFirefoxPwaInstall,
        pkgs,
        ...
      }:
      mkFirefoxPwaInstall {
        inherit config pkgs;
        name = "cinny";
        description = "Install Cinny";
        manifestUrl = "https://app.cinny.in/manifest.json";
      };

    "software/discord".home =
      {
        config,
        lib,
        mkFirefoxPwaInstall,
        pkgs,
        ...
      }:
      let
        url = "https://discord.com/app";
        manifest = builtins.toJSON {
          name = "Discord";
          description = "Discord";
          start_url = url;
          icons = [
            {
              src = "https://discord.com/assets/favicon.ico";
              sizes = "256x256";
              type = "image/x-icon";
            }
          ];
        };
      in
      mkFirefoxPwaInstall {
        inherit config pkgs;
        name = "discord";
        description = "Install Discord";
        manifestUrl = "data:application/manifest+json,${lib.escapeURL manifest}";
        installArgs = [
          "--document-url"
          url
        ];
      };

    "software/rust-zulip".home =
      {
        config,
        lib,
        mkFirefoxPwaInstall,
        pkgs,
        ...
      }:
      let
        url = "https://rust-lang.zulipchat.com/";
        manifest = builtins.toJSON {
          name = "Rust Zulip";
          description = "Rust project Zulip";
          start_url = url;
          icons = [
            {
              src = "https://avatars.zulip.com/4715/realm/icon.png?version=2";
              sizes = "512x512";
              type = "image/png";
            }
          ];
        };
      in
      mkFirefoxPwaInstall {
        inherit config pkgs;
        name = "rust-zulip";
        description = "Install Rust Zulip";
        manifestUrl = "data:application/manifest+json,${lib.escapeURL manifest}";
        installArgs = [
          "--document-url"
          url
        ];
      };
  };
}
