{
  ray.features."software/biternet-go".home =
    _:
    { inputs, ... }:
    {
      imports = [ inputs.biternet-go.homeManagerModules.default ];

      services.biternet = {
        enable = true;
        autoStart = true;
        silentStart = true;
      };
    };
}
