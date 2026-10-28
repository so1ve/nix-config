{
  ray.features."software/ab-download-manager" = {
    home =
      _:
      { inputs, ... }:
      {
        imports = [ inputs.so1ve.homeModules.ab-download-manager ];

        programs.ab-download-manager = {
          enable = true;
          uiScale = 2;
        };
      };
  };
}
