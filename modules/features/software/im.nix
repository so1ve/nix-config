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
        description = "Install Telegram Web K as a Firefox PWA";
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
        description = "Install Cinny as a Firefox PWA";
        manifestUrl = "https://app.cinny.in/manifest.json";
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
        description = "Install Rust Zulip as a Firefox PWA";
        manifestUrl = "data:application/manifest+json,${lib.escapeURL manifest}";
        installArgs = [
          "--document-url"
          url
        ];
      };
  };
}
