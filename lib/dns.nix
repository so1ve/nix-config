{
  lib,
  dns,
  cloudflare,
}:

let
  fqdn = zone: name: if name == "@" then zone else "${name}.${zone}";

  zoneFor =
    hostname:
    let
      matches = lib.filter (zone: hostname == zone || lib.hasSuffix ".${zone}" hostname) (
        lib.attrNames dns.zones
      );
      sorted = lib.sort (a: b: builtins.stringLength a > builtins.stringLength b) matches;
    in
    assert lib.assertMsg (sorted != [ ]) "No DNS zone declared for Tunnel hostname ${hostname}";
    builtins.head sorted;

  manual = lib.concatMap (
    zone:
    lib.mapAttrsToList (key: record: {
      inherit zone record;
      key = "${zone}/${key}";
      hostname = fqdn zone record.name;
    }) dns.zones.${zone}.records
  ) (lib.attrNames dns.zones);

  routes = lib.concatMap (
    tunnelName:
    lib.mapAttrsToList (hostname: route: {
      inherit hostname route tunnelName;
      zone = zoneFor hostname;
    }) cloudflare.tunnels.${tunnelName}.ingress
  ) (lib.attrNames cloudflare.tunnels);

  hostnames = map (route: route.hostname) routes;
  manualNames = map (entry: entry.hostname) manual;
  collisions = lib.intersectLists manualNames hostnames;

  recordResources = lib.listToAttrs (
    map (
      entry:
      lib.nameValuePair entry.key (
        {
          zone_id = dns.zones.${entry.zone}.cloudflare.zoneId;
          name = entry.hostname;
          inherit (entry.record) type ttl;
          inherit (entry.record.cloudflare) proxied;
        }
        // lib.optionalAttrs (entry.record.content != null) { inherit (entry.record) content; }
        // lib.optionalAttrs (entry.record.priority != null) { inherit (entry.record) priority; }
        // lib.optionalAttrs (entry.record.comment != null) { inherit (entry.record) comment; }
        // lib.optionalAttrs (entry.record.data != { }) { inherit (entry.record) data; }
        // lib.optionalAttrs (entry.record.cloudflare.settings != { }) {
          inherit (entry.record.cloudflare) settings;
        }
      )
    ) manual
  );

  tunnelRecords = lib.listToAttrs (
    map (
      entry:
      lib.nameValuePair "tunnel/${entry.hostname}" {
        zone_id = dns.zones.${entry.zone}.cloudflare.zoneId;
        name = entry.hostname;
        type = "CNAME";
        content = "${cloudflare.tunnels.${entry.tunnelName}.id}.cfargotunnel.com";
        ttl = 1;
        proxied = true;
      }
    ) routes
  );

  # Lifecycle applies to resources, so each record keeps its own stable resource name.
  resourceName =
    key: lib.replaceStrings [ "/" "." "-" "*" ] [ "_slash_" "_dot_" "_dash_" "_star_" ] key;

  allRecords = recordResources // tunnelRecords;
  lifecycleByKey = lib.listToAttrs (
    map (entry: lib.nameValuePair entry.key entry.record.lifecycle) manual
  );
in
assert lib.assertMsg (
  cloudflare.tunnels == { } || cloudflare.accountId != null
) "Cloudflare Tunnel configuration requires ray.cloudflare.accountId";
assert lib.assertMsg (
  lib.length hostnames == lib.length (lib.unique hostnames)
) "A DNS hostname belongs to more than one Cloudflare Tunnel";
assert lib.assertMsg (
  collisions == [ ]
) "DNS records duplicate Tunnel hostnames: ${lib.concatStringsSep ", " collisions}";
assert lib.assertMsg (
  lib.length (lib.attrNames allRecords)
  == lib.length (lib.unique (map resourceName (lib.attrNames allRecords)))
) "DNS record keys produce duplicate OpenTofu resource names";
{
  resource.cloudflare_dns_record = lib.mapAttrs' (
    key: value:
    lib.nameValuePair (resourceName key) (
      value
      // lib.optionalAttrs ((lifecycleByKey.${key} or { }) != { }) {
        lifecycle = lifecycleByKey.${key};
      }
    )
  ) allRecords;

  resource.cloudflare_zero_trust_tunnel_cloudflared_config = lib.mapAttrs (_: tunnel: {
    account_id = cloudflare.accountId;
    tunnel_id = tunnel.id;
    config.ingress =
      lib.mapAttrsToList (
        hostname: route:
        {
          inherit hostname;
          inherit (route) service;
        }
        // lib.optionalAttrs (route.originRequest.httpHostHeader != null) {
          origin_request.http_host_header = route.originRequest.httpHostHeader;
        }
      ) tunnel.ingress
      ++ [ { service = "http_status:404"; } ];
  }) cloudflare.tunnels;
}
