{
  ray.features."software/sunloginclient" = {
    nixos =
      { inputs, username, ... }:
      {
        imports = [ inputs.so1ve.nixosModules.sunloginclient ];

        services.sunloginclient = {
          enable = true;
          uiScale = 2;
        };
        users.users.${username}.extraGroups = [ "sunloginclient" ];
      };
  };
}
