import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/flaresolverr/flaresolverr",
  tag: "latest",
});
