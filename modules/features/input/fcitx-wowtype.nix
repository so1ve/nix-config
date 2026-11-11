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

    home = _: fcitx5.home "wowtype";
  };
}
