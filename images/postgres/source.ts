import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/library/postgres",
  tag: "latest",
});
