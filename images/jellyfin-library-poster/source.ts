import { oci } from "nix-repin";

export default oci.tag({
  repository: "docker.io/evanqu/jellyfin-library-poster",
  tag: "latest",
});
