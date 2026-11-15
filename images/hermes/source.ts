import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/nousresearch/hermes-agent",
  tag: "stable",
});
