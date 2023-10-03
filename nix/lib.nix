{
  bash-strict-mode,
  self,
  treefmt-nix,
}: {
  configuration = {
    modules ? [],
    pkgs,
    lib ? pkgs.lib,
    extraSpecialArgs ? {},
    check ? true,
  }:
    import ../modules {
      inherit check extraSpecialArgs lib pkgs;
      configuration = {
        imports =
          modules
          ++ [
            {
              _module.args.bash-strict-mode = bash-strict-mode;
              _module.args.treefmt-nix = treefmt-nix;
              programs.project-manager.path = toString ../.;
            }
          ];
      };
      modules = builtins.attrValues self.projectModules;
    };

  ## Takes the same arguments as `configuration`, but
  ## defaults to loading configuration from `$src/.config/project` and
  ## `$src/.config/project/user`.
  defaultConfiguration = src: {modules ? [], ...} @ args: let
    config = src + /.config/project;
    userConfig = config + /user;
  in
    self.lib.configuration
    (args
      // {
        modules =
          modules
          ++ [config]
          ++ (
            if builtins.pathExists userConfig
            then [userConfig]
            else []
          );
      });
}
