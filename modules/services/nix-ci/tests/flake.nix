## A stand-in for a flake’s outputs, covering each way a derivation can be
## excluded, in each kind of per-system output.
let
  drv = name: attrs: {type = "derivation";} // attrs // {inherit name;};
in {
  checks.x86_64-linux = {
    plain = drv "plain" {};
    unsandboxed = drv "unsandboxed" {__noChroot = true;};
    needs-kvm = drv "needs-kvm" {requiredSystemFeatures = ["kvm"];};
    needs-recursive-nix =
      drv "needs-recursive-nix" {requiredSystemFeatures = ["recursive-nix"];};
  };
  devShells.x86_64-linux.unsandboxed = drv "unsandboxed" {__noChroot = true;};
  packages.x86_64-linux = {
    plain = drv "plain" {};
    needs-recursive-nix =
      drv "needs-recursive-nix" {requiredSystemFeatures = ["recursive-nix"];};
  };
}
