import { oci } from "nix-repin";

export default oci.image({
  repository: "ghcr.io/abrechen2/sublarr",
  tagPattern: "1\\.[0-9]+\\.[0-9]+",
});
