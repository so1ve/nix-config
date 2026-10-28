{ inputs }:

host: nixos: {
  inherit (host) hostname;
  sshUser = host.username;
  interactiveSudo = nixos.config.security.sudo-rs.wheelNeedsPassword;

  profiles.system = {
    user = "root";
    path = inputs.deploy-rs.lib.${host.system}.activate.nixos nixos;
  };
}
