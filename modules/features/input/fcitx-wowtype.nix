let
  fcitx5 = import ../../../lib/mk-fcitx5.nix;
in
{
  ray.features."input/fcitx-wowtype" = {
    nixos =
      _:
      { inputs, pkgs, ... }:
      let
        wowtype = inputs.wowtype.packages.${pkgs.stdenv.hostPlatform.system}.default;
      in
      fcitx5.nixos pkgs "wowtype" [ wowtype ];

    home =
      _:
      { lib, ... }:
      {
        imports = [ fcitx5.home ];

        # A profile saved by Fcitx5 takes precedence over the system profile.
        xdg.configFile."fcitx5/profile".text = lib.generators.toINI { } (fcitx5.profile "wowtype");
      };
  };
}
