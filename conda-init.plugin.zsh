0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"

if [ -z ${Z_INIT_CONDA_PREFIX+x} ]; then
	echo "Set Z_INIT_CONDA_PREFIX to YOUR_CONDA_ROOT_PATH";
else
	__conda_setup="$($Z_INIT_CONDA_PREFIX/bin/conda 'shell.zsh' 'hook' 2>/dev/null)"
	if [ $? -eq 0 ]; then
		eval "$__conda_setup"
	else
		if [ -f "$Z_INIT_CONDA_PREFIX/etc/profile.d/conda.sh" ]; then
			. "$Z_INIT_CONDA_PREFIX/etc/profile.d/conda.sh"
		else
			export PATH="$Z_INIT_CONDA_PREFIX/bin:$PATH"
		fi
	fi
	unset __conda_setup
	unset Z_INIT_CONDA_PREFIX
fi
