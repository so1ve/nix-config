{
  ray.features."software/telegram-web" = {
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
        name = "telegram-web";
        description = "Install Telegram Web K as a Firefox PWA";
        manifestUrl = "https://web.telegram.org/k/site.webmanifest";
      };
  };
}
