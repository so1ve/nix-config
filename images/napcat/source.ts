import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/mlikiowa/napcat-docker",
  tag: "latest",
});
