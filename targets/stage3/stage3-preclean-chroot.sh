#!/bin/bash

export RUN_DEFAULT_FUNCS="no"

source /tmp/chroot-functions.sh

update_env_settings
show_debug

cleanup_stages

if [ -n "${clst_DISTCC}" ]
then
	portageq match / sys-devel/distcc 2>&1 | grep -s -q distcc
	if [ $? == 0 ]; then
		run_merge -C sys-devel/distcc || exit 1
	fi
fi

if [ -n "${clst_ICECREAM}" ]
then
	run_merge -C sys-devel/icecream || exit 1
fi
