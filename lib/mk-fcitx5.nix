let
  theme = "mellow-wechat";

  profile = inputMethod: {
    "Groups/0" = {
      Name = "Default";
      "Default Layout" = "us";
      DefaultIM = inputMethod;
    };

    "Groups/0/Items/0".Name = inputMethod;
    "Groups/0/Items/1".Name = "keyboard-us";
    GroupOrder."0" = "Default";
  };
in
{
  inherit profile;

  nixos = pkgs: inputMethod: addons: {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";

      fcitx5 = {
        addons = addons ++ [ pkgs.fcitx5-mellow-themes ];
        waylandFrontend = true;
        settings.inputMethod = profile inputMethod;
      };
    };

    # Qt does not support the text-input-v3 protocol used by Niri.
    environment.variables.QT_IM_MODULE = "fcitx";
  };

  home =
    { lib, pkgs, ... }:
    let
      themes = "${pkgs.fcitx5-mellow-themes}/share/fcitx5/themes";
    in
    {
      # XDG autostart services are not restarted by Home Manager's service switch.
      home.activation.restartFcitx =
        lib.hm.dag.entryAfter
          [
            "onFilesChange"
            "reloadSystemd"
          ]
          ''
            if ${pkgs.systemd}/bin/systemctl --user is-active --quiet app-org.fcitx.Fcitx5@autostart.service; then
              run ${pkgs.systemd}/bin/systemctl --user restart app-org.fcitx.Fcitx5@autostart.service
            fi
          '';

      # Qt client-side candidate windows look for themes in the XDG data paths.
      xdg.dataFile = {
        "fcitx5/themes/${theme}".source = "${themes}/${theme}";
        "fcitx5/themes/${theme}-dark".source = "${themes}/${theme}-dark";
      };

      # Fcitx5-Qt only reads the user-level config for the candidate window.
      xdg.configFile = {
        "fcitx5/config".text = lib.generators.toINI { } {
          "Hotkey/TriggerKeys"."0" = "Super+space";
          # Let the input engine handle Shift for switching between Chinese and English.
          "Hotkey/AltTriggerKeys"."0" = "";
        };

        "fcitx5/conf/keyboard.conf".text = lib.generators.toINI { } {
          # Disable Ctrl+Alt+H/J to avoid collisions with Herdr navigation.
          "Hint Trigger" = { };
          "One Time Hint Trigger" = { };
        };

        "fcitx5/conf/classicui.conf".text = ''
          Theme=${theme}
          DarkTheme=${theme}-dark
          UseDarkTheme=True
        '';
      };
    };
}
