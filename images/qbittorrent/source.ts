import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/linuxserver/qbittorrent",
  tag: "latest",
});
