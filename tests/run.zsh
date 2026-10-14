#!/usr/bin/env zsh
# Isolated installations exercise public behavior without Conda or network access.
emulate -L zsh
setopt errexit

plugin=${0:A:h:h}/conda-init.plugin.zsh
work=$(mktemp -d)
work=${work:A}
trap 'rm -rf -- "$work"' EXIT
root="$work/install with spaces"
home="$work/home"
mkdir -p "$root"/{bin,etc/profile.d,envs/torch/bin} "$home"

cat > "$root/etc/profile.d/functions.zsh" <<'EOF'
export CONDA_EXE="$FAKE_ROOT/bin/conda"
export CONDA_SHLVL=${CONDA_SHLVL:-0}
conda() {
  print -r -- "conda:$*" >> "$TEST_LOG"
  [[ $1 == activate ]] || return 1
  export CONDA_DEFAULT_ENV=$2 CONDA_SHLVL=1
  if [[ $2 == /* ]]; then
    export CONDA_PREFIX=$2
  elif [[ $2 == base ]]; then
    export CONDA_PREFIX=$FAKE_ROOT
  else
    export CONDA_PREFIX="$FAKE_ROOT/envs/$2"
  fi
  path=("$CONDA_PREFIX/bin" $path)
}
EOF
print -r -- 'source "$FAKE_ROOT/etc/profile.d/functions.zsh"' > "$root/etc/profile.d/conda.sh"

cat > "$root/bin/conda" <<'EOF'
#!/bin/zsh -f
print -r -- "cli-conda:$*" >> "$TEST_LOG"
[[ $1 == shell.zsh && $2 == hook ]] || exit 1
# Modern Conda rejects both aliases at once, even when their values agree.
[[ -z ${CONDA_AUTO_ACTIVATE+x} || -z ${CONDA_AUTO_ACTIVATE_BASE+x} ]] || exit 1
print -r -- 'source "$FAKE_ROOT/etc/profile.d/functions.zsh"'
[[ ${CONDA_AUTO_ACTIVATE_BASE:-${CONDA_AUTO_ACTIVATE:-true}} == false ]] ||
  print -r -- 'conda activate "${FAKE_DEFAULT_ENV:-base}"'
EOF
cat > "$root/bin/mamba" <<'EOF'
#!/bin/zsh -f
print -r -- "cli-mamba:$*" >> "$TEST_LOG"
[[ ${FAKE_MAMBA_MODE:-} != fail ]] || exit 1
[[ ${FAKE_MAMBA_MODE:-} != empty ]] || exit 0
[[ $1 == shell ]] || exit 1
if [[ $2 == hook ]]; then
  print -r -- 'mamba() { "$MAMBA_EXE" "$@"; }'
  print -r -- "export MAMBA_EXE=${(q)0}"
elif [[ $2 == activate && $3 == -s && $4 == zsh ]]; then
  target=$5
  prefix=$target
  [[ $target == /* ]] || prefix="$MAMBA_ROOT_PREFIX/envs/$target"
  [[ $target != base ]] || prefix=$MAMBA_ROOT_PREFIX
  print -r -- "export CONDA_DEFAULT_ENV=${(q)target} CONDA_PREFIX=${(q)prefix} CONDA_SHLVL=1"
  print -r -- 'path=("$CONDA_PREFIX/bin" $path)'
else
  exit 1
fi
EOF
chmod +x "$root/bin/conda" "$root/bin/mamba"

typeset -i passed=0
run() {
  local name=$1 code=$2 output
  shift 2
  : > "$work/calls"
  if output=$(env -i HOME="$home" PATH=/usr/bin:/bin FAKE_ROOT="$root" \
    TEST_LOG="$work/calls" PLUGIN="$plugin" "$@" /bin/zsh -f -c '
      setopt errexit
      ready() {
        source "$PLUGIN" || return
        [[ $CONDA_DEFAULT_ENV == torch && ${path[1]:A} == "$FAKE_ROOT/envs/torch/bin" ]]
      }
    '"$code" 2>&1); then
    print -r -- "ok - $name"
    (( ++passed ))
  else
    print -u2 -r -- "FAIL - $name" "$output"
    return 1
  fi
}

run 'native Mamba, spaces, and no Python hook' '
  ready
  [[ $(<"$TEST_LOG") == "cli-mamba:shell activate -s zsh torch" ]]
  (( $+functions[conda] ))
  (( !$+parameters[root_prefix] && !$+parameters[setup] ))
  [[ $Z_INIT_CONDA_PREFIX == "$FAKE_ROOT" ]]
  source "$PLUGIN"
  lines=("${(@f)$(<"$TEST_LOG")}")
  (( $#lines == 1 ))
' Z_INIT_CONDA_PREFIX="$root" Z_INIT_CONDA_ENV=torch

for mode in fail empty; do
  run "Mamba $mode falls back to Conda" '
    ready
    [[ $(<"$TEST_LOG") == *"conda:activate torch" ]]
  ' Z_INIT_CONDA_PREFIX="$root" Z_INIT_CONDA_ENV=torch FAKE_MAMBA_MODE=$mode
done

mv "$root/bin/mamba" "$root/bin/mamba.disabled"
run 'Conda-only installation' '
  ready
  [[ $(<"$TEST_LOG") == "conda:activate torch" ]]
' Z_INIT_CONDA_PREFIX="$root" Z_INIT_CONDA_ENV=torch
mv "$root/bin/mamba.disabled" "$root/bin/mamba"

run 'unset environment follows native configured default' '
  ready
  [[ $(<"$TEST_LOG") == *"cli-conda:shell.zsh hook"* ]]
' Z_INIT_CONDA_PREFIX="$root" FAKE_DEFAULT_ENV=torch
run 'native auto-activation disabled' '
  source "$PLUGIN"
  [[ -z ${CONDA_PREFIX:-} && $CONDA_SHLVL == 0 ]]
' Z_INIT_CONDA_PREFIX="$root" CONDA_AUTO_ACTIVATE=false
run 'explicit empty environment initializes only' '
  source "$PLUGIN"
  (( $+functions[conda] ))
  [[ -z ${CONDA_PREFIX:-} && ! -s $TEST_LOG ]]
' Z_INIT_CONDA_PREFIX="$root" Z_INIT_CONDA_ENV=''
run 'inherited environment and PATH are retained' '
  source "$PLUGIN"
  [[ $CONDA_DEFAULT_ENV == torch && $CONDA_SHLVL == 2 ]]
  [[ $path[1] == "$CONDA_PREFIX/bin" && ! -s $TEST_LOG ]]
' Z_INIT_CONDA_PREFIX="$root" CONDA_PREFIX="$root/envs/torch" CONDA_DEFAULT_ENV=torch CONDA_SHLVL=2
run 'matching absolute environment prefix skips activation' '
  source "$PLUGIN"
  [[ ! -s $TEST_LOG ]]
' Z_INIT_CONDA_PREFIX="$root" Z_INIT_CONDA_ENV="$root/envs/torch" CONDA_PREFIX="$root/envs/torch" CONDA_DEFAULT_ENV=torch CONDA_SHLVL=1
run 'explicit different environment overrides inherited environment' '
  ready
  [[ $(<"$TEST_LOG") == "cli-mamba:shell activate -s zsh torch" ]]
' Z_INIT_CONDA_PREFIX="$root" Z_INIT_CONDA_ENV=torch CONDA_PREFIX="$root" CONDA_DEFAULT_ENV=base CONDA_SHLVL=1
run 'absolute startup prefix is supported' '
  source "$PLUGIN"
  [[ $CONDA_PREFIX == "$Z_INIT_CONDA_ENV" && $path[1] == "$CONDA_PREFIX/bin" ]]
' Z_INIT_CONDA_PREFIX="$root" Z_INIT_CONDA_ENV="$root/envs/torch"
ln -s "$root/envs/torch" "$home/environment"
run 'symlink startup prefix avoids repeated activation' '
  source "$PLUGIN"
  source "$PLUGIN"
  [[ $CONDA_PREFIX == "$FAKE_ROOT/envs/torch" ]]
  lines=("${(@f)$(<"$TEST_LOG")}")
  (( $#lines == 1 ))
' Z_INIT_CONDA_PREFIX="$root" Z_INIT_CONDA_ENV="$home/environment"

for variable in CONDA_ROOT MAMBA_ROOT_PREFIX _CONDA_ROOT; do
  run "root detection: $variable" 'ready' "$variable=$root" Z_INIT_CONDA_ENV=torch
done
run 'root detection: Conda executable' 'ready' CONDA_EXE="$root/bin/conda" Z_INIT_CONDA_ENV=torch
mkdir "$work/path"
ln -s "$root/bin/conda" "$work/path/conda"
run 'root detection: symlink on PATH' 'ready' PATH="$work/path:/usr/bin:/bin" Z_INIT_CONDA_ENV=torch
ln -s "$root" "$home/miniforge3"
run 'root detection: standard HOME installation' 'ready' Z_INIT_CONDA_ENV=torch
rm "$home/miniforge3"
run 'no installation is a quiet no-op' '
  output=$(source "$PLUGIN" 2>&1)
  [[ -z $output ]]
'
run 'missing configured root reports failure' '
  result=0
  output=$(source "$PLUGIN" 2>&1) || result=$?
  [[ $result == 1 && $output == *"installation not found"* ]]
' Z_INIT_CONDA_PREFIX="$work/missing"

mv "$root/etc/profile.d/conda.sh" "$root/etc/profile.d/conda.sh.disabled"
run 'hook fallback suppresses activation and restores user settings' '
  before_zero=$0
  setopt noclobber
  source "$PLUGIN"
  [[ -z ${CONDA_PREFIX:-} && $CONDA_AUTO_ACTIVATE == true && $CONDA_AUTO_ACTIVATE_BASE == true ]]
  [[ $options[noclobber] == on && $0 == $before_zero ]]
  [[ $(<"$TEST_LOG") == "cli-conda:shell.zsh hook" ]]
' Z_INIT_CONDA_PREFIX="$root" Z_INIT_CONDA_ENV='' CONDA_AUTO_ACTIVATE=true CONDA_AUTO_ACTIVATE_BASE=true
mv "$root/bin/conda" "$root/bin/conda.disabled"
run 'Mamba-only installation uses its shell hook' '
  ready
  (( $+functions[mamba] ))
  [[ $(<"$TEST_LOG") == *"cli-mamba:shell hook -s zsh"* ]]
' Z_INIT_CONDA_PREFIX="$root" Z_INIT_CONDA_ENV=torch

print -r -- "$passed checks passed"
