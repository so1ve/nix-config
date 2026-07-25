{
  ray.features."software/gaming" = {
    nixos =
      { pkgs, ... }:
      {
        programs = {
          gamemode.enable = true;
          gamescope.enable = true;

          steam = {
            enable = true;
            extraCompatPackages = [ pkgs.proton-ge-bin ];
          };
        };
      };

    home = {
      programs.mangohud.enable = true;
    };
  };
}
