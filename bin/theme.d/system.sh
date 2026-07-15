#!/usr/bin/env bash
write_btop_theme() {
  local btop_themes_dir="$HOME/.config/btop/themes"
  local btop_conf="$HOME/.config/btop/btop.conf"
  local flavor="${THEME_NAME#catppuccin-}"
  local cache="$CATPPUCCIN_CACHE/btop-${flavor}.theme"
  local theme_name

  mkdir -p "$btop_themes_dir"

  if [[ "$THEME_NAME" == catppuccin-* && -f "$cache" ]]; then
    theme_name="catppuccin_${flavor}"
    cp "$cache" "$btop_themes_dir/${theme_name}.theme"
  else
    theme_name="dotfiles"
    cat > "$btop_themes_dir/dotfiles.theme" <<EOF2
theme[main_bg]="$BASE"
theme[main_fg]="$TEXT"
theme[title]="$TEXT"
theme[hi_fg]="$BLUE"
theme[selected_bg]="$SURFACE1"
theme[selected_fg]="$BLUE"
theme[inactive_fg]="$OVERLAY1"
theme[graph_text]="$ROSEWATER"
theme[meter_bg]="$SURFACE1"
theme[proc_misc]="$ROSEWATER"
theme[cpu_box]="$PINK"
theme[mem_box]="$GREEN"
theme[net_box]="$RED"
theme[proc_box]="$BLUE"
theme[div_line]="$SUBTLE"
theme[temp_start]="$GREEN"
theme[temp_mid]="$YELLOW"
theme[temp_end]="$RED"
theme[cpu_start]="$CYAN"
theme[cpu_mid]="$BLUE"
theme[cpu_end]="$LAVENDER"
theme[free_start]="$PINK"
theme[free_mid]="$LAVENDER"
theme[free_end]="$BLUE"
theme[cached_start]="$CYAN"
theme[cached_mid]="$BLUE"
theme[cached_end]="$LAVENDER"
theme[available_start]="$YELLOW"
theme[available_mid]="$PINK"
theme[available_end]="$RED"
theme[used_start]="$GREEN"
theme[used_mid]="$CYAN"
theme[used_end]="$CYAN"
theme[download_start]="$YELLOW"
theme[download_mid]="$PINK"
theme[download_end]="$RED"
theme[upload_start]="$GREEN"
theme[upload_mid]="$CYAN"
theme[upload_end]="$CYAN"
theme[process_start]="$CYAN"
theme[process_mid]="$LAVENDER"
theme[process_end]="$PINK"
EOF2
  fi

  if [[ -f "$btop_conf" || -L "$btop_conf" ]]; then
    btop_conf="$(_resolve_path "$btop_conf")"
    if grep -q "^color_theme" "$btop_conf"; then
      _sed_i "s|^color_theme = .*|color_theme = \"${theme_name}\"|" "$btop_conf"
    else
      echo "color_theme = \"${theme_name}\"" >> "$btop_conf"
    fi
  fi
}

write_k9s_theme() {
  mkdir -p "$DOTFILES_DIR/k9s/skins"
  cat > "$DOTFILES_DIR/k9s/skins/dotfiles.yaml" <<EOF2
k9s:
  body:
    fgColor: "$TEXT"
    bgColor: "$BASE"
    logoColor: "$BLUE"
  info:
    fgColor: "$TEXT"
    sectionColor: "$BLUE"
  help:
    fgColor: "$TEXT"
    bgColor: "$SURFACE0"
    keyColor: "$BLUE"
    numKeyColor: "$YELLOW"
    sectionColor: "$SUBTLE"
  frame:
    border:
      fgColor: "$SURFACE0"
      focusColor: "$BLUE"
    menu:
      fgColor: "$TEXT"
      fgStyle: dim
      keyColor: "$BLUE"
      numKeyColor: "$YELLOW"
    crumbs:
      fgColor: "$BASE"
      bgColor: "$BLUE"
      activeColor: "$PINK"
    status:
      newColor: "$GREEN"
      modifyColor: "$YELLOW"
      addColor: "$BLUE"
      errorColor: "$RED"
      highlightcolor: "$PINK"
      killColor: "$SUBTLE"
      completedColor: "$CYAN"
    title:
      fgColor: "$TEXT"
      bgColor: "$BASE"
      highlightColor: "$BLUE"
      counterColor: "$YELLOW"
      filterColor: "$PINK"
  views:
    table:
      fgColor: "$TEXT"
      bgColor: "$BASE"
EOF2
}
