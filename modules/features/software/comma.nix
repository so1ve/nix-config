{
  ray.features."software/comma".home =
    { inputs, ... }:
    {
      imports = [ inputs.nix-index-database.homeModules.default ];

      programs.nix-index-database.comma.enable = true;
    };
}
