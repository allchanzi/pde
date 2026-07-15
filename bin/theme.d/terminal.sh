#!/usr/bin/env bash
write_alacritty_theme() {
  local flavor="${THEME_NAME#catppuccin-}"
  local cache="$CATPPUCCIN_CACHE/alacritty-${flavor}.toml"

  if [[ "$THEME_NAME" == catppuccin-* && -f "$cache" ]]; then
    {
      printf '[window]\nopacity = %s\ndecorations_theme_variant = "%s"\n\n' "$ALACRITTY_OPACITY" "$DECORATIONS_THEME_VARIANT"
      cat "$cache"
    } > "$DOTFILES_DIR/alacritty/theme.toml"
    return
  fi

  cat > "$DOTFILES_DIR/alacritty/theme.toml" <<EOF2
[window]
opacity = $ALACRITTY_OPACITY
decorations_theme_variant = "$DECORATIONS_THEME_VARIANT"

[colors.primary]
background = "$BASE"
foreground = "$TEXT"
dim_foreground = "$SUBTLE"
bright_foreground = "$TEXT"

[colors.cursor]
text = "$BASE"
cursor = "$ROSEWATER"

[colors.vi_mode_cursor]
text = "$BASE"
cursor = "$LAVENDER"

[colors.selection]
text = "$BASE"
background = "$ROSEWATER"

[colors.search.matches]
foreground = "$BASE"
background = "$SUBTEXT0"

[colors.search.focused_match]
foreground = "$BASE"
background = "$GREEN"

[colors.footer_bar]
foreground = "$BASE"
background = "$SUBTEXT0"

[colors.hints.start]
foreground = "$BASE"
background = "$YELLOW"

[colors.hints.end]
foreground = "$BASE"
background = "$SUBTEXT0"

[colors.line_indicator]
foreground = "None"
background = "None"

[colors.normal]
black = "$SURFACE1"
red = "$RED"
green = "$GREEN"
yellow = "$YELLOW"
blue = "$BLUE"
magenta = "$PINK"
cyan = "$CYAN"
white = "$SUBTEXT1"

[colors.bright]
black = "$SURFACE2"
red = "$RED"
green = "$GREEN"
yellow = "$YELLOW"
blue = "$BLUE"
magenta = "$PINK"
cyan = "$CYAN"
white = "$SUBTEXT0"

[colors.dim]
black = "$SURFACE0"
red = "$RED"
green = "$GREEN"
yellow = "$YELLOW"
blue = "$BLUE"
magenta = "$PINK"
cyan = "$CYAN"
white = "$OVERLAY1"
EOF2
}

write_kitty_theme() {
  local flavor="${THEME_NAME#catppuccin-}"
  local cache="$CATPPUCCIN_CACHE/kitty-${flavor}.conf"

  if [[ "$THEME_NAME" == catppuccin-* && -f "$cache" ]]; then
    cp "$cache" "$DOTFILES_DIR/kitty/theme.conf"
    return
  fi

  cat > "$DOTFILES_DIR/kitty/theme.conf" <<EOF2
# Cursor
cursor                  $ROSEWATER
cursor_text_color       $BASE
cursor_blink_interval   0

# Primary
foreground              $TEXT
background              $BASE
selection_foreground    $BASE
selection_background    $ROSEWATER

# Normal
color0  $SURFACE1
color1  $RED
color2  $GREEN
color3  $YELLOW
color4  $BLUE
color5  $PINK
color6  $CYAN
color7  $SUBTEXT1

# Bright
color8  $SURFACE2
color9  $RED
color10 $GREEN
color11 $YELLOW
color12 $BLUE
color13 $PINK
color14 $CYAN
color15 $SUBTEXT0
EOF2
}

write_ghostty_theme() {
  local flavor="${THEME_NAME#catppuccin-}"
  local cache="$CATPPUCCIN_CACHE/ghostty-${flavor}.conf"

  if [[ "$THEME_NAME" == catppuccin-* && -f "$cache" ]]; then
    cp "$cache" "$DOTFILES_DIR/ghostty/theme"
    return
  fi

  cat > "$DOTFILES_DIR/ghostty/theme" <<EOF2
background = ${BASE#\#}
foreground = ${TEXT#\#}
cursor-color = ${ROSEWATER#\#}
cursor-text = ${BASE#\#}
selection-background = ${ROSEWATER#\#}
selection-foreground = ${BASE#\#}
palette = 0=${SURFACE1}
palette = 1=${RED}
palette = 2=${GREEN}
palette = 3=${YELLOW}
palette = 4=${BLUE}
palette = 5=${PINK}
palette = 6=${CYAN}
palette = 7=${SUBTEXT1}
palette = 8=${SURFACE2}
palette = 9=${RED}
palette = 10=${GREEN}
palette = 11=${YELLOW}
palette = 12=${BLUE}
palette = 13=${PINK}
palette = 14=${CYAN}
palette = 15=${SUBTEXT0}
EOF2
}
