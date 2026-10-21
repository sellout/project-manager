## By default, checks that need features Nix CI’s builders don’t have (e.g.,
## `recursive-nix`) are excluded, along with unsandboxed ones.
{
  _module.args.self = import ../flake.nix;

  services.nix-ci.enable = true;

  nmt.script = ''
    assertFileExists "project-files/nix-ci.nix"
    assertFileContent "project-files/nix-ci.nix" ${./nix-ci.nix}
  '';
}
