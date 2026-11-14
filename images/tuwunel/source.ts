import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/jevolk/tuwunel",
  tag: "latest",
});
