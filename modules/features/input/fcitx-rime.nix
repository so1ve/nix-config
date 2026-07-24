{
  ray.features."input/fcitx-rime" = {
    nixos =
      { pkgs, ... }:
      let
        rimeWithIce = pkgs.fcitx5-rime.override {
          rimeDataPkgs = [ pkgs.rime-ice ];
        };
      in
      {
        i18n.inputMethod = {
          enable = true;
          type = "fcitx5";

          fcitx5 = {
            addons = [ rimeWithIce ];
            waylandFrontend = true;

            settings.inputMethod = {
              "Groups/0" = {
                Name = "Default";
                "Default Layout" = "us";
                DefaultIM = "rime";
              };

              "Groups/0/Items/0".Name = "keyboard-us";
              "Groups/0/Items/1".Name = "rime";
              GroupOrder."0" = "Default";
            };
          };
        };

        # Qt does not support the text-input-v3 protocol used by Niri.
        environment.variables.QT_IM_MODULE = "fcitx";
      };

    home = {
      xdg.dataFile."fcitx5/rime/default.custom.yaml".text = ''
        patch:
          __include: rime_ice_suggestion:/
      '';
    };
  };
}
