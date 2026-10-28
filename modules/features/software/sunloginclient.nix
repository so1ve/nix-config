{
  ray.features."software/sunloginclient" = {
    nixos =
      _:
      { inputs, username, ... }:
      {
        imports = [ inputs.so1ve.nixosModules.sunloginclient ];

        services.sunloginclient = {
          enable = true;
          uiScale = 1;
        };
        users.users.${username}.extraGroups = [ "sunloginclient" ];
      };
  };
}
