#!/bin/bash -ue
#
# Build RPMs for Ganeti and Tools

# single packages
GANETI_DEPENDES_PACKAGES1="ghc-Crypto ghc-curl ghc-regex-pcre"
# in order of dependencies
# (contravariant | tagged -> distributive) -> comonad) -> semigroupoids
GANETI_DEPENDES_PACKAGES2="ghc-contravariant ghc-tagged ghc-distributive ghc-comonad ghc-semigroupoids"
# (base-orphans | bifunctors | profunctors | generic-derivin | reflectiong) -> lens
GANETI_DEPENDES_PACKAGES3="ghc-base-orphans ghc-bifunctors ghc-profunctors ghc-generic-deriving ghc-reflection ghc-lens"
# ganeti
GANETI_PACKAGES="ganeti ganeti-instance-debootstrap"

# integ-ganeti repo
INTEG_GANETI_REPO_PACKAGES="integ-ganeti-release"

# sng-image
SNF_IMAGE_PACKAGES="python-prctl snf-image"

# all packages
PACKAGES="${GANETI_DEPENDES_PACKAGES1}
            ${GANETI_DEPENDES_PACKAGES2}
            ${GANETI_DEPENDES_PACKAGES3}
            ${GANETI_PACKAGES}
            ${SNF_IMAGE_PACKAGES}
            ${INTEG_GANETI_REPO_PACKAGES}"

# Directories
PACKAGER="$(basename "${0}")"
PACKAGER_DIR="$(cd "$(dirname "${0}")" && echo "${PWD}")"
PACKAGER_RPM_DIR="${PACKAGER_DIR}/rpmbuild"

# Includes
#. ${PACKAGER_DIR}/package-config
#. ${PACKAGER_DIR}/package-prebuild

RPM_DIST=$(egrep "\%dist" /etc/rpm/macros.dist | awk '{ print $2 }' | sed -E 's|^(\..*)\..*|\1|')

# Usage
usage() {
    cat << _EOF_

Usage:
    ${PACKAGER} [-a|-p package...]]

    Options:
        -a Build all packages (ganeti and its dependencies and integ-ganeti repo, snf-image).
        -d Build ganeti dependencies packages only.
        -p Build the specified package(s) only. Available packages are:
            ganeti dependencies:
                ${GANETI_DEPENDES_PACKAGES1}
                ${GANETI_DEPENDES_PACKAGES2}
                ${GANETI_DEPENDES_PACKAGES3}
            ganeti:
                ${GANETI_PACKAGES}
            snf-image:
                ${SNF_IMAGE_PACKAGES}
            integ-ganeti-repo:
                ${INTEG_GANETI_REPO_PACKAGES}

        -i Install built packages.
        -u Uninstall installed packages.

        -l List ghc dependencies in target packages.

_EOF_
}

# Check old package
check_oldpackage() {
    PACKAGE="${1}"
    local is_first=0
    is_overwrite="-1"

    SPEC_FILE="SPECS/${PACKAGE}.spec"
    RPM_VERSION=$(egrep -i "^Version:" "${SPEC_FILE}" | awk '{ print $2 }')
    RPM_RELEASE=$(egrep -i "^Release:" "${SPEC_FILE}" | awk '{ print $2 }' | cut -d'%' -f 1)
    RPM_ARCHITECTURE=$(egrep -i "^(BuildArchitectures|BuildArch):" "${SPEC_FILE}" | awk '{ print $2 }' | tail -1)

    if [ -z "${RPM_ARCHITECTURE}" ]; then
        RPM_ARCHITECTURE=$(uname -i)
    fi

    RPM_FILE="RPMS/${RPM_ARCHITECTURE}/${PACKAGE}-${RPM_VERSION}-${RPM_RELEASE}${RPM_DIST}.${RPM_ARCHITECTURE}.rpm"
    if [ -f "${RPM_FILE}" ]; then
        while [ ${is_overwrite} != "y" -a ${is_overwrite} != "n" ];
        do
            if [ ${is_first} -ne 0 ]; then
                echo "-> BAD INPUT: Invalid charactor."
            fi
            echo "${RPM_FILE} already exists."
            echo -n "Do you want to overwrite it? [y/n]: "
            read is_overwrite < /dev/tty
            is_first=1
        done
    else
        is_overwrite="y"
    fi
}

# Uninstall packages
uninstall_package() {
    echo "Uninstall packages..."
    REMOVE_PACKAGES=""
    for PACKAGE in ${@}; do
        REMOVE_PACKAGES="${REMOVE_PACKAGES} ${PACKAGE} ${PACKAGE}-devel ${PACKAGE}-debuginfo"
    done
    yum -y remove ${REMOVE_PACKAGES}
}

# Build packages
build_package() {
    for PACKAGE in ${@}; do
        echo "Building package for ${PACKAGE}..."
        pushd "${PACKAGER_RPM_DIR}/${PACKAGE}"
        check_oldpackage "${PACKAGE}"
        local PACKAGE_SPEC_FILE="SPECS/${PACKAGE}.spec"
        if [ ${is_overwrite} = "y" ]; then
            # Install build dependencies
            yum-builddep -y "${PACKAGE_SPEC_FILE}"

            # Download source and patch files
            if [ ! -d SOURCES ]; then
                mkdir SOURCES
            fi
            spectool -g -A "${PACKAGE_SPEC_FILE}" -C SOURCES/

            # Build package
            rpmbuild \
                --define "%_topdir ${PACKAGER_RPM_DIR}/${PACKAGE}" \
                --define "%dist ${RPM_DIST}" \
                -ba "${PACKAGE_SPEC_FILE}"

        fi

        # Install packages
        [ "${INSTALL_MODE}" = "yes" ] && yum -y install RPMS/*/*.rpm

        echo
        popd
    done
}

ghc_dependency_list() {
    EGREP_REGEX=""
    for PACKAGE in ${PACKAGES}; do
        if [[ ${PACKAGE} =~ ^ghc-(.*) ]]; then
            EGREP_REGEX="${EGREP_REGEX}|${BASH_REMATCH[1]}"
        fi
    done

    # echo "REGEX: \"(${EGREP_REGEX:1})-"
    ghc-pkg dot | tred | egrep "\"(${EGREP_REGEX:1})-" | sort
}

# Main
main() {
    [ $# -lt 1 ] && usage && exit 1

    # See how we're called.
    INSTALL_MODE="no"
    UNINSTALL_MODE="no"
    BUILD_ALL="no"
    BUILD_PACKAGES="no"
    BUILD_GANETI_DEPENDES_PACKAGES="no"
    GHC_DEPENDENCY_LIST="no"
    while getopts iuadpl OPT; do
        case "${OPT}" in
            "i" )
                INSTALL_MODE="yes" ;;
            "u" )
                UNINSTALL_MODE="yes" ;;
            "a" )
                BUILD_ALL="yes" ;;
            "d" )
                BUILD_GANETI_DEPENDES_PACKAGES="yes" ;;
            "p" )
                BUILD_PACKAGES="yes" ;;
            "l" )
                GHC_DEPENDENCY_LIST="yes" ;;
            * )
                usage
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    # Uninstall task
    if [ "${UNINSTALL_MODE}" = "yes" ]; then
        uninstall_package "${@}"
    fi

    # Build task
    if [ "${BUILD_ALL}" = "yes" ]; then
        build_package "${PACKAGES}"
    elif [ "${BUILD_GANETI_DEPENDES_PACKAGES}" = "yes" ]; then
        build_package "${GANETI_DEPENDES_PACKAGES1} ${GANETI_DEPENDES_PACKAGES2} ${GANETI_DEPENDES_PACKAGES3}"
    elif [ "${BUILD_PACKAGES}" = "yes" ]; then
        build_package "${@}"
    fi

    # GHC dependency list task
    if [ "${GHC_DEPENDENCY_LIST}" = "yes" ]; then
        ghc_dependency_list
    fi
}

[ ${#BASH_SOURCE[@]} = 1 ] && main "${@}"

