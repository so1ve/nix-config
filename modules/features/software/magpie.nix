{
  ray.features."software/magpie".home =
    _:
    { inputs, pkgs, ... }:
    let
      agy = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.antigravity-cli;
      startMagpie = pkgs.writeShellScript "start-magpie" ''
        export PATH="${agy}/bin:$PATH"
        exec ${pkgs.so1ve.magpie}/bin/magpie serve --web
      '';
    in
    {
      home.packages = [
        pkgs.so1ve.magpie
        agy
      ];

      systemd.user.services.magpie = {
        Unit = {
          Description = "magpie model gateway";
          Documentation = [ "https://usemagpie.ai/docs/start" ];
        };

        Service = {
          ExecStart = "${startMagpie}";
          Restart = "on-failure";
          RestartSec = 2;
        };

        Install.WantedBy = [ "default.target" ];
      };
    };
}
