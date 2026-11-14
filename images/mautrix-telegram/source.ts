import { oci } from "nix-repin";

export default oci.image({
  repository: "dock.mau.dev/mautrix/telegram",
  tagPattern: "v[0-9]+\\.[0-9]+",
  stripPrefix: "v",
});
