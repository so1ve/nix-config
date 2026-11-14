import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/linuxserver/prowlarr",
  tag: "latest",
});
