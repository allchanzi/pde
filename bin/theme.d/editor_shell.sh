#!/usr/bin/env bash
write_zsh_syntax_theme() {
  local flavor="${THEME_NAME#catppuccin-}"
  local cache="$CATPPUCCIN_CACHE/zsh-syntax-${flavor}.zsh"
  local out="$DOTFILES_DIR/zsh/shell/catppuccin-syntax.zsh"

  if [[ "$THEME_NAME" == catppuccin-* && -f "$cache" ]]; then
    cp "$cache" "$out"
  else
    > "$out"
  fi
}

write_fzf_theme() {
  local flavor="${THEME_NAME#catppuccin-}"
  local cache="$CATPPUCCIN_CACHE/fzf-${flavor}.sh"
  local out="$DOTFILES_DIR/zsh/shell/catppuccin-fzf.zsh"

  if [[ "$THEME_NAME" == catppuccin-* && -f "$cache" ]]; then
    cp "$cache" "$out"
  else
    > "$out"
  fi
}

write_p10k_theme() {
  local p10k="$HOME/.p10k.zsh"

  [[ -f "$p10k" ]] || return

  _p10k_set() {
    local key="$1" value="$2"
    if grep -q "^  typeset -g ${key}=" "$p10k"; then
      _sed_i "s|^  typeset -g ${key}=.*|  typeset -g ${key}='${value}'|" "$p10k"
    else
      _sed_i "/^  typeset -g POWERLEVEL9K_BACKGROUND=/a\\
  typeset -g ${key}='${value}'
" "$p10k"
    fi
  }

  _p10k_set POWERLEVEL9K_DIR_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_VCS_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_STATUS_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_BACKGROUND_JOBS_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_DIRENV_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_ASDF_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_VIRTUALENV_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_ANACONDA_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_PYENV_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_GOENV_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_NODENV_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_NVM_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_NODEENV_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_TIME_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_DIR_FOREGROUND "$TEXT"
  _p10k_set POWERLEVEL9K_DIR_SHORTENED_FOREGROUND "$SUBTLE"
  _p10k_set POWERLEVEL9K_DIR_ANCHOR_FOREGROUND "$BLUE"
  _p10k_set POWERLEVEL9K_OS_ICON_FOREGROUND "$BLUE"
  _p10k_set POWERLEVEL9K_VCS_CLEAN_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_VCS_MODIFIED_FOREGROUND "$YELLOW"
  _p10k_set POWERLEVEL9K_STATUS_OK_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_STATUS_OK_PIPE_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_STATUS_ERROR_FOREGROUND "$RED"
  _p10k_set POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND "$RED"
  _p10k_set POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND "$RED"
  _p10k_set POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND "$SUBTEXT0"
  _p10k_set POWERLEVEL9K_COMMAND_EXECUTION_TIME_PREFIX "%F{$SUBTLE}took "
  _p10k_set POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND "$BLUE"
  _p10k_set POWERLEVEL9K_DIRENV_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_ASDF_FOREGROUND "$BLUE"
  _p10k_set POWERLEVEL9K_VIRTUALENV_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_ANACONDA_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_PYENV_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_GOENV_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_NODENV_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_NVM_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_NODEENV_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_TIME_FOREGROUND "$TEXT"
  _p10k_set POWERLEVEL9K_TIME_PREFIX "%F{$SUBTLE}at "
  _p10k_set POWERLEVEL9K_VI_MODE_BACKGROUND "$BASE"
  _p10k_set POWERLEVEL9K_VI_MODE_NORMAL_FOREGROUND "$GREEN"
  _p10k_set POWERLEVEL9K_VI_MODE_VISUAL_FOREGROUND "$LAVENDER"
  _p10k_set POWERLEVEL9K_VI_MODE_OVERWRITE_FOREGROUND "$YELLOW"
  _p10k_set POWERLEVEL9K_VI_MODE_INSERT_FOREGROUND "$BLUE"
  _p10k_set POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR "%F{$SURFACE2}"
  _p10k_set POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR "%F{$SURFACE2}"
  for state in VIINS VICMD VIVIS VIOWR; do
    _p10k_set "POWERLEVEL9K_PROMPT_CHAR_OK_${state}_FOREGROUND" "$TEXT"
    _p10k_set "POWERLEVEL9K_PROMPT_CHAR_ERROR_${state}_FOREGROUND" "$RED"
  done
  _p10k_set POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_COLOR "$GREEN"
  _sed_i "/^  typeset -g POWERLEVEL9K_PROMPT_CHAR_.*_FOREGROUND='POWERLEVEL9K_PROMPT_CHAR_/d" "$p10k"
  _sed_i "s|^      local       meta=.*|      local       meta='%F{${SUBTLE}}'  # theme subtle foreground|" "$p10k"
  _sed_i "s|^      local      clean=.*|      local      clean='%F{${GREEN}}'  # theme green foreground|" "$p10k"
  _sed_i "s|^      local   modified=.*|      local   modified='%F{${YELLOW}}'  # theme yellow foreground|" "$p10k"
  _sed_i "s|^      local  untracked=.*|      local  untracked='%F{${BLUE}}'  # theme blue foreground|" "$p10k"
  _sed_i "s|^      local conflicted=.*|      local conflicted='%F{${RED}}'  # theme red foreground|" "$p10k"
  _sed_i "s|%244Ftook |%F{${SUBTLE}}took |g" "$p10k"
  _sed_i "s|%244Fat |%F{${SUBTLE}}at |g" "$p10k"
  _sed_i "s|%242F\\uE0B1|%F{${SURFACE2}}|g" "$p10k"
  _sed_i "s|%242F\\uE0B3|%F{${SURFACE2}}|g" "$p10k"
  _sed_i "s|%F{${SURFACE2}}uE0B1|%F{${SURFACE2}}|g" "$p10k"
  _sed_i "s|%F{${SURFACE2}}uE0B3|%F{${SURFACE2}}|g" "$p10k"
  unset -f _p10k_set
}
