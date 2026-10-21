## With `supportedSystemFeatures = null`, only unsandboxed checks are excluded.
{
  _module.args.self = import ../flake.nix;

  services.nix-ci = {
    enable = true;
    supportedSystemFeatures = null;
  };

  nmt.script = ''
    assertFileExists "project-files/nix-ci.nix"
    assertFileContent "project-files/nix-ci.nix" ${./nix-ci.nix}
  '';
}
