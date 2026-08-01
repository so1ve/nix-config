{
  ray.features."software/ab-download-manager" = {
    home =
      { inputs, ... }:
      {
        imports = [ inputs.nur.repos.so1ve.homeModules.ab-download-manager ];

        programs.ab-download-manager = {
          enable = true;
          uiScale = 1.75;
        };
      };
  };
}
