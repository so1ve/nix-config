{
  ray.features."hardware/battery" = {
    nixos = {
      systemd.services.battery-charge-thresholds = {
        description = "Configure battery charge thresholds";
        wantedBy = [ "multi-user.target" ];

        unitConfig.ConditionPathExists = "/sys/class/power_supply/BAT0/charge_control_end_threshold";

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          battery_path=/sys/class/power_supply/BAT0

          # Disable the start threshold while changing both limits so that
          # transitions in either direction cannot temporarily become invalid.
          echo 0 > "$battery_path/charge_control_start_threshold"
          echo 90 > "$battery_path/charge_control_end_threshold"
          echo 85 > "$battery_path/charge_control_start_threshold"
        '';
      };
    };
  };
}
