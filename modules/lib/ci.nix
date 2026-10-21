## Helpers shared by Nix-based CI service modules.
{lib}: let
  ## The per-system flake outputs that hold derivations for CI to build.
  derivationOutputs = ["checks" "devShells" "packages"];

  ## Whether a CI service whose builders provide `supportedSystemFeatures` can
  ## build `drv`: it can’t if `drv` disables the sandbox or requires a system
  ## feature the builders don’t provide. `supportedSystemFeatures = null` means
  ## allow any features.
  canBuild = supportedSystemFeatures: drv: let
    isSupported = feature:
      supportedSystemFeatures
      == null
      || lib.elem feature supportedSystemFeatures;
  in
    !(drv.__noChroot or false)
    && lib.all isSupported (drv.requiredSystemFeatures or []);

  ## The derivations in `attrs` that the CI service can’t build.
  unbuildable = supportedSystemFeatures:
    lib.filterAttrs (_: drv: !canBuild supportedSystemFeatures drv);

  ## Attribute paths (as used by the services’ exclusion lists) of the
  ## derivations in `attrs`, which lives at `prefix`, that the CI service can’t
  ## build.
  excludedPaths = supportedSystemFeatures: prefix: attrs:
    map (name: "${prefix}.${name}")
    (builtins.attrNames (unbuildable supportedSystemFeatures attrs));
in {
  inherit canBuild excludedPaths unbuildable;

  ## Attribute paths of everything in `flake`’s per-system derivation outputs
  ## (`checks`, `devShells`, `packages`) for `system` that the CI service can’t
  ## build.
  excludedFlakePaths = supportedSystemFeatures: flake: system:
    lib.concatMap (output:
      excludedPaths supportedSystemFeatures "${output}.${system}"
      (flake.${output}.${system} or {}))
    derivationOutputs;
}
