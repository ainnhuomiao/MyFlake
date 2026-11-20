{ me, appearance, ... }:
{
  programs = {
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        syntax-theme = "Catppuccin ${appearance.catppuccinName}";
        line-numbers = true;
      };
    };
    git = {
      enable = true;
      settings = {
        user = {
          name = me.githubUserName;
          email = me.email;
        };
        pull = {
          rebase = false;
        };
        url = {
          "git@github.com:" = {
            insteadOf = "gh:";
          };
          "https://github.com/" = {
            insteadOf = "github:";
          };
        };
        core = {
          quotepath = false;
        };
      };
      signing = {
        key = null;
        signByDefault = false;
      };
    };
  };
}
