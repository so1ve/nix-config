{
  name,
  domain,
  port,
}:
{
  "traefik.enable" = "true";
  "traefik.http.routers.${name}.rule" = "Host(`${domain}`)";
  "traefik.http.routers.${name}.tls" = "true";
  "traefik.http.services.${name}.loadbalancer.server.port" = toString port;
}
