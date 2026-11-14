import { oci } from "nix-repin";

export default oci.tag({
  repository: "ghcr.io/so1ve/yanqi",
  tag: "latest",
});
