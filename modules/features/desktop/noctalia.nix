{
  ray.features."desktop/noctalia" = {
    nixos =
      {
        inputs,
        registry,
        ...
      }:
      let
        cache = registry.binaryCaches.noctalia;
      in
      {
        imports = [ inputs.noctalia.nixosModules.default ];

        programs.noctalia = {
          enable = true;
          recommendedServices.enable = true;
        };

        nix.settings = {
          extra-substituters = [ cache.url ];
          extra-trusted-public-keys = [ cache.publicKey ];
        };
      };

    home =
      {
        config,
        mkDotfilesSymlink,
        ...
      }:
      {
        xdg.configFile."noctalia".source = mkDotfilesSymlink {
          inherit config;
          name = "noctalia";
        };
      };
  };
}
