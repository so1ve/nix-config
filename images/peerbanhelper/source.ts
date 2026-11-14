import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/ghostchu/peerbanhelper",
  tag: "latest",
});
