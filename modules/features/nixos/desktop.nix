{
  ray.features."nixos/desktop" = {
    nixos = {
      services = {
        displayManager.sddm.enable = true;
        pulseaudio.enable = false;

        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };
      };

      security.rtkit.enable = true;
    };
  };
}
