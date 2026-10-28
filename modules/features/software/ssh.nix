{
  ray.features."software/ssh".home = _: { programs.ssh.enable = true; };

  ray.features."software/ssh/admin" = {
    requires.allOf = [
      "software/ssh"
      "security/agenix"
    ];

    home =
      _:
      {
        config,
        hostname,
        inputs,
        ...
      }:
      let
        keyName = "ssh-admin-${hostname}";
      in
      {
        age.secrets.${keyName} = {
          file = "${inputs.self}/secrets/${keyName}.age";
          path = "${config.home.homeDirectory}/.ssh/${keyName}";
        };
      };
  };
}
