{
  ray.features."software/ab-download-manager" = {
    home =
      { inputs, ... }:
      {
        imports = [ inputs.ab-download-manager.homeModules.default ];

        programs.ab-download-manager = {
          enable = true;
          uiScale = 2;
        };
      };
  };
}
