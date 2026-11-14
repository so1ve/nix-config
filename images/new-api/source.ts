import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/calciumion/new-api",
  tag: "latest",
});
