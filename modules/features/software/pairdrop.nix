{
  ray.features."software/pairdrop" = {
    requires = [ "software/chrome" ];

    nixos = {
      ray.chromeWebApps = [
        {
          url = "https://pairdrop.net/";
          custom_name = "PairDrop";
        }
      ];
    };
  };
}
