{
  ray.features = {
    "software/ghostty" = {
      home = {
        programs.ghostty = {
          enable = true;
          settings.font-family = "R Maple Mono NF CN";
        };
      };
    };

    "software/kitty" = {
      home = {
        programs.kitty = {
          enable = true;
          settings = {
            font_family = "R Maple Mono NF CN";
            linux_display_server = "wayland";
          };
        };

        home.sessionVariables.TERMINAL = "kitty";
      };
    };
  };
}
