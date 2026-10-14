# zplugin-conda-init

Conda shell initialization for Zsh, with optional native Mamba activation.
Works with Zinit (formerly Zplugin) or direct sourcing; no helper plugin is required.

## Usage

```zsh
Z_INIT_CONDA_ENV=torch
zinit light lzcn/zplugin-conda-init
```

The plugin looks for an existing installation. Set the root explicitly for a
custom location:

```zsh
Z_INIT_CONDA_PREFIX="/path/to/miniforge3"
Z_INIT_CONDA_ENV=base
zinit light lzcn/zplugin-conda-init
```

Load synchronously when the environment must be ready for the first command.
For optional deferred loading, add `zinit ice wait"0" lucid` before `light`.
This moves initialization after the prompt; it does not reduce activation work.
The `zplugin` command name also works. Direct sourcing is supported:

```zsh
source /path/to/zplugin-conda-init/conda-init.plugin.zsh
```

## Configuration

| Variable | Behavior |
| --- | --- |
| `Z_INIT_CONDA_PREFIX` | Installation root; spaces in paths are supported. |
| `Z_INIT_CONDA_ENV` | Startup environment name or absolute prefix. Empty initializes functions without activating. Unset follows native auto-activation settings. |

Root detection checks `CONDA_ROOT`, `MAMBA_ROOT_PREFIX`, an existing Conda
integration, and resolved `conda`/`mamba` executables on `PATH`. It also checks
`~/miniforge3`, `~/miniconda3`, `~/mambaforge`, and `~/anaconda3`. No installation
is a quiet no-op; an explicitly configured missing root reports an error.

Do not use `CONDA_PREFIX` as configuration: it describes the active environment.
The existing `Z_INIT_CONDA_PREFIX` setting is supported and is no longer unset
after loading, so sourcing the plugin again works.

## Startup behavior

- With an explicit environment, load `conda.sh` directly and prefer installed
  Mamba 2 for activation. Conda's normal shell functions remain available.
- Missing, older, failing, or empty-output Mamba falls back to `conda activate`.
- An inherited environment is retained unless an explicit different environment
  was requested; its `bin` directory is restored to the front of `PATH`.
- With no explicit environment in a fresh shell, use the standard Conda hook to
  honor settings such as `auto_activate` and `default_activation_env`.
- Mamba-only installations use their native shell hook.

The installed tools produce activation scripts and environment state. Generated
activation code is not cached: it includes the current `PATH`. The plugin does
not parse `.condarc`, download installers, or create environments.

## Checks

```sh
zsh -n conda-init.plugin.zsh
zsh tests/run.zsh
```
