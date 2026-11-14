{ lib }:

let
  render = configuration: import ../lib/dns.nix ({ inherit lib; } // configuration);

  record =
    overrides:
    {
      name = "@";
      type = "MX";
      content = "mx1.example.net";
      ttl = 300;
      priority = 10;
      data = { };
      comment = null;
      lifecycle = { };
      cloudflare = {
        proxied = false;
        settings = { };
      };
    }
    // overrides;

  route = {
    service = "http://127.0.0.1:8081";
    originRequest.httpHostHeader = "cache.example.net";
  };

  base = {
    dns.zones."example.net" = {
      provider = "cloudflare";
      cloudflare.zoneId = "zone-id";
      records = {
        mail1 = record { };
        mail2 = record {
          content = "mx2.example.net";
          priority = 20;
        };
        homelab = record {
          name = "*";
          type = "AAAA";
          content = "2001:db8::1";
          priority = null;
          lifecycle.ignore_changes = [ "content" ];
        };
      };
    };
    cloudflare = {
      accountId = "account-id";
      tunnels.racknerd = {
        id = "tunnel-id";
        ingress."cache.example.net" = route;
      };
    };
  };

  output = render base;
  records = lib.attrValues output.resource.cloudflare_dns_record;
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
in
lib.runTests {
  testMxRecordsKeepSeparatePriorities = {
    expr = map (r: { inherit (r) name content priority; }) (lib.filter (r: r.type == "MX") records);
    expected = [
      {
        name = "example.net";
        content = "mx1.example.net";
        priority = 10;
      }
      {
        name = "example.net";
        content = "mx2.example.net";
        priority = 20;
      }
    ];
  };

  testTunnelPublishesDnsAndOrigin = {
    expr = {
      dns = lib.filter (r: r.type == "CNAME") records;
      ingress = output.resource.cloudflare_zero_trust_tunnel_cloudflared_config.racknerd.config.ingress;
    };
    expected = {
      dns = [
        {
          zone_id = "zone-id";
          name = "cache.example.net";
          type = "CNAME";
          content = "tunnel-id.cfargotunnel.com";
          ttl = 1;
          proxied = true;
        }
      ];
      ingress = [
        {
          hostname = "cache.example.net";
          service = "http://127.0.0.1:8081";
          origin_request.http_host_header = "cache.example.net";
        }
        { service = "http_status:404"; }
      ];
    };
  };

  testDdclientOwnsOnlyContent = {
    expr = (lib.findFirst (r: r.type == "AAAA") null records).lifecycle;
    expected.ignore_changes = [ "content" ];
  };

  testRejectsManualTunnelRecord = {
    expr = fails (
      render (
        lib.recursiveUpdate base {
          dns.zones."example.net".records.cache = record { name = "cache"; };
        }
      )
    );
    expected = true;
  };

  testRejectsTwoTunnelsForOneName = {
    expr = fails (
      render (
        lib.recursiveUpdate base {
          cloudflare.tunnels.other = {
            id = "other-id";
            ingress."cache.example.net" = route;
          };
        }
      )
    );
    expected = true;
  };

  testRejectsMissingZone = {
    expr = fails (render (base // { dns.zones = { }; }));
    expected = true;
  };

  testUsesClosestZone = {
    expr =
      (lib.findFirst (r: r.type == "CNAME") null (
        lib.attrValues
          (render (
            lib.recursiveUpdate base {
              dns.zones."cache.example.net" = {
                provider = "cloudflare";
                cloudflare.zoneId = "child-zone";
                records = { };
              };
            }
          )).resource.cloudflare_dns_record
      )).zone_id;
    expected = "child-zone";
  };
}
