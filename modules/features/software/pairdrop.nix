{
  ray.features."software/pairdrop" = {
    requires.allOf = [ "software/chrome" ];

    nixos = _: {
      ray.chromeWebApps = [
        {
          url = "https://pairdrop.net/";
          custom_name = "PairDrop";
          appId = "ndhgbicjlckgkkcbfiloaamoiindppmp";
        }
      ];
    };
  };
}
