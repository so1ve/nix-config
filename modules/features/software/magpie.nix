{
  ray.features."software/magpie".home =
    _:
    { inputs, pkgs, ... }:
    let
      magpie = (import inputs.so1ve { inherit pkgs; }).magpie;
    in
    {
      home.packages = [ magpie ];

      systemd.user.services.magpie = {
        Unit = {
          Description = "magpie model gateway";
          Documentation = [ "https://usemagpie.ai/docs/start" ];
        };

        Service = {
          ExecStart = "${magpie}/bin/magpie serve --web";
          Restart = "on-failure";
          RestartSec = 2;
        };

        Install.WantedBy = [ "default.target" ];
      };
    };
}
