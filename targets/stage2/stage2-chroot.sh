#!/bin/sh
# Copyright 1999-2004 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo/src/catalyst/targets/stage2/stage2-chroot.sh,v 1.11 2005/04/04 17:48:33 rocket Exp $

. /tmp/chroot-functions.sh

update_env_settings

setup_myfeatures
setup_myemergeopts


## setup the environment
export FEATURES="${clst_myfeatures}"
GRP_STAGE23_USE="$(portageq envvar GRP_STAGE23_USE)"

## START BUILD
/usr/portage/scripts/bootstrap.sh ${bootstrap_opts} || exit 1
