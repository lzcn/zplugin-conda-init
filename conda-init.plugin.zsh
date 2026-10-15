# Keep initialization state local; native shell functions remain available.
() {
  emulate -L zsh
  local root_prefix="${Z_INIT_CONDA_PREFIX:-${CONDA_ROOT:-${MAMBA_ROOT_PREFIX:-${_CONDA_ROOT:-}}}}"
  if [[ -z $root_prefix ]]; then
    local executable="${CONDA_EXE:-${MAMBA_EXE:-${commands[conda]:-${commands[mamba]:-}}}}"
    [[ -z $executable ]] || root_prefix=${executable:A:h:h}
  fi
  if [[ -z $root_prefix ]]; then
    local candidate
    for candidate in "$HOME"/{miniforge3,miniconda3,mambaforge,anaconda3}; do
      if [[ -r "$candidate/etc/profile.d/conda.sh" || -x "$candidate/bin/conda" ||
        -x "$candidate/bin/mamba" ]]; then
        root_prefix=$candidate
        break
      fi
    done
  fi
  [[ -n $root_prefix ]] || return 0
  if [[ ! -d $root_prefix ]]; then
    print -u2 -- "conda-init: installation not found: $root_prefix"
    return 1
  fi

  local conda_exe="$root_prefix/bin/conda" mamba_exe="$root_prefix/bin/mamba"
  [[ -x $mamba_exe ]] || mamba_exe=${commands[mamba]:-}
  local setup target_env="${Z_INIT_CONDA_ENV-}"
  [[ $target_env != /* ]] || target_env=${target_env:A}
  local -i explicit_env=${+Z_INIT_CONDA_ENV} inherited_env=0
  [[ -n ${CONDA_PREFIX:-} && ${CONDA_SHLVL:-0} == <1-> ]] && inherited_env=1

  # Suppress hook auto-activation without exporting both Conda option aliases.
  if (( explicit_env || inherited_env )); then
    local +x CONDA_AUTO_ACTIVATE
    local -x CONDA_AUTO_ACTIVATE_BASE=false MAMBA_AUTO_ACTIVATE_BASE=false
  fi

  if (( explicit_env || inherited_env )) && [[ -r "$root_prefix/etc/profile.d/conda.sh" ]]; then
    source "$root_prefix/etc/profile.d/conda.sh" || return
  elif [[ -x $conda_exe ]] && setup="$("$conda_exe" shell.zsh hook 2>/dev/null)" && [[ -n $setup ]]; then
    eval "$setup" || return
  elif [[ -r "$root_prefix/etc/profile.d/conda.sh" ]]; then
    source "$root_prefix/etc/profile.d/conda.sh" || return
  elif [[ -x $mamba_exe ]] &&
    setup="$(MAMBA_ROOT_PREFIX=$root_prefix "$mamba_exe" shell hook -s zsh 2>/dev/null)" && [[ -n $setup ]]; then
    eval "$setup" || return
  else
    [[ ! -d "$root_prefix/bin" ]] || path=("$root_prefix/bin" ${path:#"$root_prefix/bin"})
    print -u2 -- "conda-init: no working shell integration at $root_prefix"
    return 1
  fi

  if (( explicit_env )) && [[ -n $target_env && ${CONDA_DEFAULT_ENV:-} != "$target_env" &&
    ${CONDA_PREFIX:-} != "$target_env" ]]; then
    # Prefer native Mamba; retain Conda compatibility.
    if [[ -x $mamba_exe ]] &&
      setup="$(MAMBA_ROOT_PREFIX=$root_prefix "$mamba_exe" shell activate -s zsh "$target_env" 2>/dev/null)" && [[ -n $setup ]]; then
      eval "$setup" || return
      rehash
    elif (( $+functions[conda] )); then
      conda activate "$target_env" || return
    else
      print -u2 -- "conda-init: could not activate environment: $target_env"
      return 1
    fi
  fi

  # Login shells and shellenv can reorder an inherited environment's PATH.
  if [[ -n ${CONDA_PREFIX:-} && -d "$CONDA_PREFIX/bin" ]]; then
    path=("$CONDA_PREFIX/bin" ${path:#"$CONDA_PREFIX/bin"})
  fi
}
