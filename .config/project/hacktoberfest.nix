## Settings for participating in [Hacktoberfest](https://hacktoberfest.com/participation/#maintainers)
##
## TODO: Add similar settings for GitLab, if that’s possible.
{
  services.github.settings = {
    repository.topics = ["hacktoberfest"];
    labels = {
      hacktoberfest = {
        color = "#000000"; # black
        description = "Issues you want contributors to help with.";
      };
      hacktoberfest-accepted = {
        color = "#ff7518"; # pumpkin
        description = "Indicates acceptance for Hacktoberfest criteria, even if not merged yet.";
      };
      spam = {
        color = "#ffc0cb"; #pink
        description = "Topic created in bad faith. Services like Hacktoberfest use this to identify bad actors.";
      };
      invalid = {
        color = "#333333"; #dark grey
        description = "Unaccepted contributions that haven’t been closed for some reason.";
      };
    };
  };
}
