{
  ray.features."software/telegram-web" = {
    home =
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
  };
}
