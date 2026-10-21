## By default, Garnix is assumed to support every system feature, so only
## unsandboxed checks are excluded.
{lib, ...}: {
  ## The test harness doesn’t provide these, so this stands in for the subset of
  ## Flaky’s `forGarnixSystems` that we need.
  _module.args = {
    flaky.lib.forGarnixSystems = systems: lib.flip lib.concatMap systems;
    self = import ../../../nix-ci/tests/flake.nix;
    supportedSystems = ["x86_64-linux"];
  };

  services.garnix.enable = true;

  nmt.script = ''
    assertFileExists "project-files/garnix.yaml"
    assertFileContent "project-files/garnix.yaml" ${./garnix.yaml}
  '';
}
