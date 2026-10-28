{
  ray.features."software/comma".home =
    _:
    { inputs, ... }:
    {
      imports = [ inputs.nix-index-database.homeModules.default ];

      programs.nix-index-database.comma.enable = true;
    };
}
