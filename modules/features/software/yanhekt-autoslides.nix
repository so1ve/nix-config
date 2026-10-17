{
  ray.features."software/yanhekt-autoslides".home =
    { inputs, pkgs, ... }:
    {
      home.packages = [
        (import inputs.so1ve { inherit pkgs; }).yanhekt-autoslides
      ];
    };
}
