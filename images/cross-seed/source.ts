import { oci } from "nix-repin";

export default oci.tag({
  repository: "ghcr.io/cross-seed/cross-seed",
  tag: "latest",
});
