{
  ray.features."desktop/audio" = {
    nixos = {
      services = {
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
