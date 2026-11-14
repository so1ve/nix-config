import { oci } from "nix-repin";

export default oci.image({
  repository: "ghcr.io/dockur/windows",
  tagPattern: "6\\.[0-9]+",
});
