{
  bash-strict-mode,
  project-manager,
  treefmt-nix,
}: {
  configuration = {
    self,
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
              _module.args.self = self;
              _module.args.treefmt-nix = treefmt-nix;
              programs.project-manager.path = toString ../.;
            }
          ];
      };
      modules = builtins.attrValues project-manager.projectModules;
    };

  ## Takes the same arguments as `configuration`, but
  ## defaults to loading configuration from `$PROJECT_ROOT/.config/project` and
  ## `$PROJECT_ROOT/.config/project/user`.
  defaultConfiguration = {
    self,
    modules ? [],
    ...
  } @ args: let
    projectConfig = "${self}/.config/project";
    userConfig = "${projectConfig}/user";
  in
    project-manager.lib.configuration
    (args
      // {
        modules =
          modules
          ++ [projectConfig]
          ++ (
            if builtins.pathExists userConfig
            then [userConfig]
            else []
          );
      });
}
