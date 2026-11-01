{
  ray.features."software/biternet".home =
    _:
    { inputs, ... }:
    {
      imports = [ inputs.biternet.homeManagerModules.default ];

      services.biternet = {
        enable = true;
        autoStart = true;
        silentStart = true;
      };
    };
}
