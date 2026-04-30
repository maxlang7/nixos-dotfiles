{pkgs-unstable, ...}:
{
  programs.zed-editor = {
    enable = true;
    package = pkgs-unstable.zed-editor-fhs;
    userSettings = {
      autosave = {
        after_delay = {
          milliseconds = 1000;
        };
      };

      agent_servers = {
        claude-acp = {
          type = "registry";
        };
      };

      icon_theme = {
        mode = "dark";
        light = "Zed (Default)";
        dark = "Material Icon Theme";
      };

      session = {
        trust_all_worktrees = true;
      };

      ui_font_size = 16;
      buffer_font_size = 15;

      theme = {
        mode = "dark";
        light = "One Light";
        dark = "Gruvbox Dark";
      };

      project_panel = {
        dock = "left";
      };

      outline_panel = {
        dock = "left";
      };

      collaboration_panel = {
        dock = "right";
      };

      agent = {
        dock = "right";
        favorite_models = [];
        model_parameters = [];
      };

      git_panel = {
        dock = "left";
        sort_by_path = false;
      };
    };
  };
}
