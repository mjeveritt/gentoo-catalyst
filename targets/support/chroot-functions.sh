check_portage_version(){
	portage_version=`/usr/lib/portage/bin/portageq best_version / sys-apps/portage \
		| cut -d/ -f2 | cut -d- -f2,3`
	if [ -n ${portage_version} -a `echo ${portage_version} | cut -d- -f1 | cut -d. -f3` -lt '51' ]
	then
		echo "ERROR: Your portage version is too low in your seed stage.  Portage version"
		echo "2.0.51 or greater is required."
		exit 1
	fi
}

#check_genkernel_version(){
#	genkernel_version=`/usr/lib/portage/bin/portageq best_version / sys-kernel/genkernel \
#		| cut -d/ -f2 | cut -d- -f2,3`
#	if [ -n ${genkernel_version} -a `echo ${genkernel_version} | cut -d- -f1 | cut -d. -f3` -lt '3' ]
#	then
#		echo "ERROR: Your genkernel version is too low in your seed stage.  genkernel version"
#		echo "XXXXXXXXXXXXXXX or greater is required."
#		exit 1
#	fi
#}

setup_myfeatures(){

	if [ -n "${clst_CCACHE}" ]
	then
		export clst_myfeatures="${clst_myfeatures} ccache"
		if [ "${clst_AUTORESUME}" = "1" -a -e /tmp/.clst_ccache ]
		then
		    echo "CCACHE Autoresume point found not emerging ccache"
		else
		    emerge --oneshot --nodeps -b -k ccache && touch /tmp/.clst_ccache || exit 1
		    touch /tmp/.clst_ccache
		fi
	fi

	if [ -n "${clst_DISTCC}" ]
	then
		export clst_myfeatures="${clst_myfeatures} distcc"
		export DISTCC_HOSTS="${clst_distcc_hosts}"
		if [ "${clst_AUTORESUME}" = "1" -a -e /tmp/.clst_distcc ]
		then
		    echo "DISTCC Autoresume point found not emerging distcc"
		else
		    USE="-gtk -gnome" emerge --oneshot --nodeps -b -k distcc && touch /tmp/.clst_distcc || exit 1 
		fi
	fi
}

setup_myemergeopts(){
	if [ -n "${clst_PKGCACHE}" ]
	then
		export clst_myemergeopts="--usepkg --buildpkg --newuse"
        	export bootstrap_opts="-r"
	fi

	if [ -n "${clst_FETCH}" ]
	then
		export clst_myemergeopts="${clst_myemergeopts} -f"
	        export bootstrap_opts="-f"
	fi
}


setup_portage(){
    # portage needs to be merged manually with USE="build" set to avoid frying our
    # make.conf. emerge system could merge it otherwise.
 
    if [ "${clst_AUTORESUME}" = "1" -a -e /tmp/.clst_portage ]
    then
	echo "Portage Autoresume point found not emerging portage"
    else
	USE="build" emerge portage && touch /tmp/.clst_portage || exit 1
    fi
}

setup_gcc(){
	if [ -x /usr/bin/gcc-config ]
	then
	       gcc_current=`gcc-config -c`
	       gcc-config 3 && source /etc/profile
	       gcc-config ${gcc_current} && source /etc/profile
	fi
}

update_env_settings(){
    /usr/sbin/env-update
    source /etc/profile
    [ -f /tmp/envscript ] && source /tmp/envscript
}

die() {
    echo "$1"
    exit 1
}

make_destpath() {
	if  [ "${1}" = "" ]
	then
		export ROOT=/
	else
		export ROOT=${1}
		if [ ! -d ${ROOT} ]
		then
        		install -d ${ROOT}
		fi
	fi
	echo "ROOT=${ROOT} emerge ...."
}

run_emerge() {

    # Sets up the ROOT= parameter
    # with no options ROOT=/
    make_destpath ${clst_root_path}
	
    if [ -n "${clst_VERBOSE}" ]
	then
		emerge ${clst_myemergeopts} -vpt $@ || exit 3
		echo "Press any key within 15 seconds to pause the build..."
		read -s -t 15 -n 1
		if [ $? -eq 0 ]
		then
			echo "Press any key to continue..."
			read -s -n 1
		fi
	fi
	emerge ${clst_myemergeopts} $@ || exit 1
}

# Functions
# Copy libs of a executable in the chroot
function copy_libs() {

	# Check if it's a dynamix exec

	ldd ${1} > /dev/null 2>&1 || return
    
	for lib in `ldd ${1} | awk '{ print $3 }'`
	do
		echo ${lib}
		if [ -e ${lib} ]
		then
			if [ ! -e ${clst_root_path}/${lib} ]
			then
				copy_file ${lib}
				[ -e "${clst_root_path}/${lib}" ] && strip -R .comment -R .note ${clst_root_path}/${lib} || echo "WARNING : Cannot strip lib ${clst_root_path}/${lib} !"
			fi
		else
			echo "WARNING : Some library was not found for ${lib} !"
		fi
	done

}

function copy_symlink() {

	STACK=${2}
	[ "${STACK}" = "" ] && STACK=16 || STACK=$((${STACK} - 1 ))

	if [ ${STACK} -le 0 ] 
	then
		echo "WARNING : ${TARGET} : too many levels of symbolic links !"
		return
	fi

	[ ! -e ${clst_root_path}/`dirname ${1}` ] && mkdir -p ${clst_root_path}/`dirname ${1}`
	[ ! -e ${clst_root_path}/${1} ] && cp -vfdp ${1} ${clst_root_path}/${1}
	
	TARGET=`readlink -f ${1}`
	if [ -h ${TARGET} ]
	then
		copy_symlink ${TARGET} ${STACK}
	else
		copy_file ${TARGET}
	fi
    }		

function copy_file() {

	f="${1}"

	if [ ! -e "${f}" ]
	then
		echo "WARNING : File not found : ${f}"
		continue
	fi

	[ ! -e ${clst_root_path}/`dirname ${f}` ] && mkdir -p ${clst_root_path}/`dirname ${f}`
	[ ! -e ${clst_root_path}/${f} ] && cp -vfdp ${f} ${clst_root_path}/${f}
	if [ -x ${f} -a ! -h ${f} ]
	then
		copy_libs ${f}
		strip -R .comment -R .note ${clst_root_path}/${f} > /dev/null 2>&1
	elif [ -h ${f} ]
	then
		copy_symlink ${f}
	fi
}


