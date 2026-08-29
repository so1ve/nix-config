{
  ray.features."software/bitgateway".home =
    { inputs, ... }:
    {
      imports = [ inputs.bitgateway.homeManagerModules.default ];

      services.bitgateway = {
        enable = true;
        autoStart = true;
        silentStart = true;
      };
    };
}
