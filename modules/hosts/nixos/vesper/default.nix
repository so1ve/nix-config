{
  ray.hosts.nixos.vesper = {
    system = "x86_64-linux";
    type = "desktop";
    username = "ray";
    stateVersion = "26.05";
    homeStateVersion = "26.05";
    hardware = ./_hardware.nix;

    features = [
      "core/nix"
      "nixos/base"
      "nixos/desktop"
      "hardware/uefi-systemd-boot"
      "home/base"
      "users/ray"
      "desktop/niri"
      "desktop/noctalia"
      "desktop/plasma"
      "input/fcitx-rime"
      "software/codex"
      "software/firefox"
      "software/ghostty"
      "software/git"
      "software/neovim"
      "software/shell"
      "software/tooling"
      "security/agenix"
      "ui/fonts"
    ];
  };
}
