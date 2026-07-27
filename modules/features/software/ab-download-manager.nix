{
  ray.features."software/ab-download-manager" = {
    home =
      { inputs, ... }:
      {
        imports = [ inputs.ab-download-manager.homeModules.ab-download-manager ];

        programs.ab-download-manager = {
          enable = true;
          uiScale = 2;
        };
      };
  };
}
