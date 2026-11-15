{ inputs }:

host: nixos: {
  inherit (host) hostname;
  sshUser = host.username;
  interactiveSudo = nixos.config.security.sudo-rs.wheelNeedsPassword;

  profiles.system = {
    user = "root";
    # Activation also waits for containers to download their images and start.
    activationTimeout = 3600;
    path = inputs.deploy-rs.lib.${host.system}.activate.nixos nixos;
  };
}
