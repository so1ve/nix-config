{
  ray.hosts.nixos.wsl = {
    system = "x86_64-linux";
    username = "ray";
    stateVersion = "26.05";
    homeStateVersion = "26.05";

    features = [
      # System
      "system/core"
      "system/nix"
      "system/wsl"
      "security/sudo"

      # User and shell
      "home/base"
      "software/shell"
      "users/ray"

      # Development
      "software/tmux"
      "software/neovim"
      "software/agent-skills"
      "software/codex"
      "software/pi"
      "software/development"
      "software/git"
      "software/tooling"
      "software/yazi"
    ];
  };
}
