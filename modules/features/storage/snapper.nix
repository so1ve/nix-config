{
  ray.features."storage/snapper" = {
    nixos =
      { username, ... }:
      let
        mkSnapperConfig =
          {
            subvolume,
            numberLimit ? 10,
            daily,
            weekly,
            monthly,
          }:
          {
            SUBVOLUME = subvolume;

            ALLOW_USERS = [ username ];
            SYNC_ACL = true;

            NUMBER_CLEANUP = true;
            NUMBER_LIMIT = numberLimit;
            NUMBER_LIMIT_IMPORTANT = 3;

            TIMELINE_CREATE = true;
            TIMELINE_CLEANUP = true;
            TIMELINE_LIMIT_HOURLY = 3;
            TIMELINE_LIMIT_DAILY = daily;
            TIMELINE_LIMIT_WEEKLY = weekly;
            TIMELINE_LIMIT_MONTHLY = monthly;
            TIMELINE_LIMIT_YEARLY = 0;
          };
      in
      {
        services.snapper = {
          snapshotRootOnBoot = true;
          persistentTimer = true;

          configs = {
            root = mkSnapperConfig {
              subvolume = "/";
              numberLimit = 5;
              daily = 3;
              weekly = 2;
              monthly = 1;
            };

            home = mkSnapperConfig {
              subvolume = "/home";
              daily = 7;
              weekly = 4;
              monthly = 2;
            };
          };
        };
      };
  };
}
