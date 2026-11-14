import { oci } from "nix-repin";

export default oci.image({
  repository: "docker.io/vaultwarden/server",
  tagPattern: "1\\.[0-9]+\\.[0-9]+",
});
