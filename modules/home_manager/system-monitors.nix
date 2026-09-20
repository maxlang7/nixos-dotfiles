{ ... }:

{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "gruvbox_dark";
      theme_background = true;
      truecolor = true;
      vim_keys = true;
      rounded_corners = true;
      graph_symbol = "braille";
      shown_boxes = "cpu mem net proc";
      update_ms = 1500;
      proc_sorting = "cpu lazy";
      proc_colors = true;
      proc_gradient = true;
      proc_mem_bytes = true;
      proc_cpu_graphs = true;
      show_uptime = true;
      check_temp = true;
      show_cpu_freq = true;
      show_disks = true;
      only_physical = true;
      net_auto = true;
      background_update = true;
    };
  };

  # htop uses the terminal's ANSI palette. Ghostty already supplies Gruvbox,
  # so the default htop scheme matches the rest of the popup suite.
  xdg.configFile."htop/htoprc".source = ../../artifacts/system-monitors/htoprc;
}
