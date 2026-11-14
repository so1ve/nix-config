import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/jxxghp/moviepilot-v3",
  tag: "latest",
});
