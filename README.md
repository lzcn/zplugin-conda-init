# zplugin-conda-init

Conda initialization for Zsh, with optional Mamba acceleration.

```zsh
# Z_INIT_CONDA_PREFIX=/path/to/miniforge3  # Optional installation root.
Z_INIT_CONDA_ENV=base
zinit light lzcn/zplugin-conda-init
```

- `Z_INIT_CONDA_PREFIX`: otherwise detect from `CONDA_ROOT`, `MAMBA_ROOT_PREFIX`,
  existing Conda integration, executables on `PATH`, or common home installations.
- `Z_INIT_CONDA_ENV`: name or absolute prefix. Empty initializes only; unset
  follows native auto-activation settings.

Loads native shell integration and prefers Mamba 2 for startup activation,
falling back to Conda when needed. Existing environments are retained unless a
different one is requested. Activation scripts and environment variables remain
managed by the installed tools; generated activation code is not cached.

The environment is ready before the first command. To defer loading instead,
put `zinit ice wait"0" lucid` before `light`.

Direct loading also works: `source /path/to/conda-init.plugin.zsh`.
