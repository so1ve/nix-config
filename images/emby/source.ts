import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/amilys/embyserver",
  tag: "beta",
});
