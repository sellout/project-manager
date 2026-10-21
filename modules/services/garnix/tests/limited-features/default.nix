## Checks that need features missing from `supportedSystemFeatures` are
## excluded, along with unsandboxed ones.
{lib, ...}: {
  ## The test harness doesn’t provide these, so this stands in for the subset of
  ## Flaky’s `forGarnixSystems` that we need.
  _module.args = {
    flaky.lib.forGarnixSystems = systems: lib.flip lib.concatMap systems;
    self = import ../../../nix-ci/tests/flake.nix;
    supportedSystems = ["x86_64-linux"];
  };

  services.garnix = {
    enable = true;
    supportedSystemFeatures = ["kvm"];
  };

  nmt.script = ''
    assertFileExists "project-files/garnix.yaml"
    assertFileContent "project-files/garnix.yaml" ${./garnix.yaml}
  '';
}
