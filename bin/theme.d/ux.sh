#!/usr/bin/env bash
_hex_to_rgb() {
  local hex="${1#\#}"
  printf "%d %d %d" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

write_zellij_theme() {
  # Always use our generated theme so Zellij matches terminal/tmux/Nvim exactly.
  _sed_i 's/^theme "[^"]*"/theme "dotfiles"/' "$DOTFILES_DIR/zellij/config.kdl"

  local BASE_R TEXT_R SUBTLE_R SURFACE0_R SURFACE1_R BLUE_R PINK_R GREEN_R YELLOW_R CYAN_R RED_R WHITE_R
  BASE_R="$(_hex_to_rgb "$BASE")"
  TEXT_R="$(_hex_to_rgb "$TEXT")"
  SUBTLE_R="$(_hex_to_rgb "$SUBTLE")"
  SURFACE0_R="$(_hex_to_rgb "$SURFACE0")"
  SURFACE1_R="$(_hex_to_rgb "$SURFACE1")"
  BLUE_R="$(_hex_to_rgb "$BLUE")"
  PINK_R="$(_hex_to_rgb "$PINK")"
  GREEN_R="$(_hex_to_rgb "$GREEN")"
  YELLOW_R="$(_hex_to_rgb "$YELLOW")"
  CYAN_R="$(_hex_to_rgb "$CYAN")"
  RED_R="$(_hex_to_rgb "$RED")"
  WHITE_R="$(_hex_to_rgb "$WHITE")"

  mkdir -p "$DOTFILES_DIR/zellij/themes"
  cat > "$DOTFILES_DIR/zellij/themes/dotfiles.kdl" <<EOF2
themes {
    dotfiles {
        text_unselected {
            base $TEXT_R
            background $BASE_R
            emphasis_0 $YELLOW_R
            emphasis_1 $CYAN_R
            emphasis_2 $GREEN_R
            emphasis_3 $PINK_R
        }
        text_selected {
            base $TEXT_R
            background $SURFACE1_R
            emphasis_0 $YELLOW_R
            emphasis_1 $CYAN_R
            emphasis_2 $GREEN_R
            emphasis_3 $PINK_R
        }
        ribbon_selected {
            base $BLUE_R
            background $BASE_R
            emphasis_0 $RED_R
            emphasis_1 $YELLOW_R
            emphasis_2 $GREEN_R
            emphasis_3 $PINK_R
        }
        ribbon_unselected {
            base $SUBTLE_R
            background $BASE_R
            emphasis_0 $RED_R
            emphasis_1 $SUBTLE_R
            emphasis_2 $BLUE_R
            emphasis_3 $PINK_R
        }
        table_title {
            base $GREEN_R
            background 0
            emphasis_0 $YELLOW_R
            emphasis_1 $CYAN_R
            emphasis_2 $GREEN_R
            emphasis_3 $PINK_R
        }
        table_cell_selected {
            base $TEXT_R
            background $SURFACE1_R
            emphasis_0 $YELLOW_R
            emphasis_1 $CYAN_R
            emphasis_2 $GREEN_R
            emphasis_3 $PINK_R
        }
        table_cell_unselected {
            base $TEXT_R
            background $BASE_R
            emphasis_0 $YELLOW_R
            emphasis_1 $CYAN_R
            emphasis_2 $GREEN_R
            emphasis_3 $PINK_R
        }
        list_selected {
            base $TEXT_R
            background $SURFACE1_R
            emphasis_0 $YELLOW_R
            emphasis_1 $CYAN_R
            emphasis_2 $GREEN_R
            emphasis_3 $PINK_R
        }
        list_unselected {
            base $TEXT_R
            background $BASE_R
            emphasis_0 $YELLOW_R
            emphasis_1 $CYAN_R
            emphasis_2 $GREEN_R
            emphasis_3 $PINK_R
        }
        frame_selected {
            base $BLUE_R
            background 0
            emphasis_0 $YELLOW_R
            emphasis_1 $CYAN_R
            emphasis_2 $PINK_R
            emphasis_3 0
        }
        frame_highlight {
            base $YELLOW_R
            background 0
            emphasis_0 $RED_R
            emphasis_1 $PINK_R
            emphasis_2 $YELLOW_R
            emphasis_3 $YELLOW_R
        }
        exit_code_success {
            base $GREEN_R
            background 0
            emphasis_0 $CYAN_R
            emphasis_1 $BASE_R
            emphasis_2 $PINK_R
            emphasis_3 $BLUE_R
        }
        exit_code_error {
            base $RED_R
            background 0
            emphasis_0 $YELLOW_R
            emphasis_1 0
            emphasis_2 0
            emphasis_3 0
        }
        multiplayer_user_colors {
            player_1 $PINK_R
            player_2 $BLUE_R
            player_3 0
            player_4 $YELLOW_R
            player_5 $CYAN_R
            player_6 0
            player_7 $RED_R
            player_8 0
            player_9 0
            player_10 0
        }
    }
}
EOF2
}

write_tmux_theme() {
  cat > "$DOTFILES_DIR/tmux/theme.conf" <<EOF2
# Pane borders
set -g pane-border-style "fg=$SURFACE0"
set -g pane-active-border-style "fg=$BLUE"

# Messages
set -g message-style "bg=$SURFACE0,fg=$TEXT"
set -g message-command-style "bg=$SURFACE0,fg=$BLUE"

# Status bar
set -g status-style "bg=$BASE,fg=$TEXT"
set -g status-position bottom
set -g status-justify left
set -g status-left-length 40
set -g status-right-length 140

# Left: session name
set -g status-left "#[fg=$BASE,bg=$BLUE,bold] #S #[fg=$BLUE,bg=$BASE]"

# Windows
setw -g window-status-separator ""
setw -g window-status-format "#[fg=$SUBTLE,bg=$BASE]  #W "
setw -g window-status-current-format "#[fg=$BLUE,bg=$BASE,bold]  #W "

# Right: git branch | date | time
set -g status-right "#[fg=$SURFACE1,bg=$BASE]#[fg=$SUBTLE,bg=$SURFACE1]  #(cd '#{pane_current_path}' 2>/dev/null && git branch --show-current 2>/dev/null) #[fg=$SURFACE0,bg=$SURFACE1]#[fg=$TEXT,bg=$SURFACE0]  %d.%m.%Y #[fg=$BLUE,bg=$SURFACE0]#[fg=$BASE,bg=$BLUE,bold]  %H:%M "
EOF2
}

write_lazygit_config() {
  local flavor="${THEME_NAME#catppuccin-}"
  local cache="$CATPPUCCIN_CACHE/lazygit-${flavor}.yml"

  if [[ "$THEME_NAME" == catppuccin-* && -f "$cache" ]]; then
    { echo "gui:"; sed 's/^/  /' "$cache"; echo ""; cat "$DOTFILES_DIR/lazygit/config.shared.yml"; } > "$DOTFILES_DIR/lazygit/config.yml"
    return
  fi

  cat > "$DOTFILES_DIR/lazygit/config.yml" <<EOF2
gui:
  theme:
    activeBorderColor:
      - "$BLUE"
      - bold
    inactiveBorderColor:
      - "$SUBTLE"
    searchingActiveBorderColor:
      - "$YELLOW"
      - bold
    optionsTextColor:
      - "$BLUE"
    selectedLineBgColor:
      - "$SURFACE0"
    selectedRangeBgColor:
      - "$SURFACE0"
    cherryPickedCommitBgColor:
      - "$SURFACE1"
    cherryPickedCommitFgColor:
      - "$BLUE"
    unstagedChangesColor:
      - "$RED"
    defaultFgColor:
      - "$TEXT"

EOF2
  cat "$DOTFILES_DIR/lazygit/config.shared.yml" >> "$DOTFILES_DIR/lazygit/config.yml"
}
