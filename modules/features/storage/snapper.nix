{
  ray.features."storage/snapper" = {
    nixos =
      { username, ... }:
      let
        mkSnapperConfig = subvolume: {
          SUBVOLUME = subvolume;

          ALLOW_USERS = [ username ];
          SYNC_ACL = true;

          NUMBER_CLEANUP = true;
          NUMBER_LIMIT = 10;
          NUMBER_LIMIT_IMPORTANT = 3;

          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_LIMIT_HOURLY = 6;
          TIMELINE_LIMIT_DAILY = 7;
          TIMELINE_LIMIT_WEEKLY = 4;
          TIMELINE_LIMIT_MONTHLY = 3;
          TIMELINE_LIMIT_YEARLY = 0;
        };
      in
      {
        services.snapper = {
          snapshotRootOnBoot = true;
          persistentTimer = true;

          configs = {
            root = mkSnapperConfig "/";
            home = mkSnapperConfig "/home";
          };
        };
      };
  };
}
