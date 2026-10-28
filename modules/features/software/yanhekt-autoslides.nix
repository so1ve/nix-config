{
  ray.features."software/yanhekt-autoslides".home =
    _:
    { inputs, pkgs, ... }:
    {
      home.packages = [
        (import inputs.so1ve { inherit pkgs; }).yanhekt-autoslides
      ];
    };
}
