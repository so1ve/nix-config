{
  ray.features."software/ab-download-manager" = {
    home =
      { inputs, pkgs, ... }:
      {
        imports = [ inputs.so1ve.homeModules.ab-download-manager ];

        programs.ab-download-manager = {
          enable = true;
          package = inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.ab-download-manager;
          uiScale = 1.75;
        };
      };
  };
}
