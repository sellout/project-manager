{
  default = {
    description = "A simple flake with project configuration";
    path = ./default;
    welcomeText = ''
      You now have a flake with a centralized project configuration!

      1. edit the project configuration in “.config/project/default.nix”.
      2. use `nix run .#project-manager -- switch` to populate the repo.
    '';
  };
}
