## Takes the same arguments as `configuration`, but defaults to loading
## configuration from `$PROJECT_ROOT/.config/project` and
## `$PROJECT_ROOT/.config/project/user`.
{configuration}: {
  self,
  modules ? [],
  ...
} @ args: let
  projectConfig = "${self}/.config/project";
  userConfig = "${projectConfig}/user";
in
  configuration
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
    })
