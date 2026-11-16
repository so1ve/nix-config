{
  ray.features."software/magpie".home =
    _:
    { pkgs, ... }:
    {
      home.packages = [ pkgs.so1ve.magpie ];

      systemd.user.services.magpie = {
        Unit = {
          Description = "magpie model gateway";
          Documentation = [ "https://usemagpie.ai/docs/start" ];
        };

        Service = {
          ExecStart = pkgs.writeShellScript "start-magpie" ''
            export PATH="${pkgs.so1ve.antigravity-cli}/bin:$PATH"
            exec ${pkgs.so1ve.magpie}/bin/magpie serve --web
          '';
          Restart = "on-failure";
          RestartSec = 2;
        };

        Install.WantedBy = [ "default.target" ];
      };
    };
}
