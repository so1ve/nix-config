import { oci } from "nix-repin";

export default oci.image({
  repository: "docker.io/library/traefik",
  tagPattern: "v3\\.[0-9]+\\.[0-9]+",
  stripPrefix: "v",
});
