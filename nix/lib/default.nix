{
  flake-utils,
  pkgsFor,
  self,
  treefmt-nix,
}: let
  configuration = import ./configuration.nix {
    inherit flake-utils pkgsFor self treefmt-nix;
  };
in {
  inherit configuration;

  defaultConfiguration =
    import ./default-configuration.nix {inherit configuration;};
}
