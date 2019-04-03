SUMMARY_${PN}-ptest ?= "${SUMMARY} - Package test files"
DESCRIPTION_${PN}-ptest ?= "${DESCRIPTION}  \
This package contains a test directory ${PTEST_PATH} for package test purposes."

PTEST_PATH ?= "${libdir}/${BPN}/ptest"
PTEST_BUILD_HOST_FILES ?= "Makefile"
PTEST_BUILD_HOST_PATTERN ?= ""

FILES_${PN}-ptest = "${PTEST_PATH}"
SECTION_${PN}-ptest = "devel"
ALLOW_EMPTY_${PN}-ptest = "1"
PTEST_ENABLED = "${@bb.utils.contains('DISTRO_FEATURES', 'ptest', '1', '0', d)}"
PTEST_ENABLED_class-native = ""
PTEST_ENABLED_class-nativesdk = ""
PTEST_ENABLED_class-cross-canadian = ""
RDEPENDS_${PN}-ptest_class-native = ""
RDEPENDS_${PN}-ptest_class-nativesdk = ""
RRECOMMENDS_${PN}-ptest += "ptest-runner"

PACKAGES =+ "${@bb.utils.contains('PTEST_ENABLED', '1', '${PN}-ptest', '', d)}"

do_configure_ptest() {
    :
}

do_configure_ptest_base() {
    do_configure_ptest
}

do_compile_ptest() {
    :
}

do_compile_ptest_base() {
    do_compile_ptest
}

do_install_ptest() {
    :
}

do_install_ptest_base() {
    if [ -f ${WORKDIR}/run-ptest ]; then
        install -D ${WORKDIR}/run-ptest ${D}${PTEST_PATH}/run-ptest
    fi
    if grep -q install-ptest: Makefile; then
        oe_runmake DESTDIR=${D}${PTEST_PATH} install-ptest
    fi
    do_install_ptest
    chown -R root:root ${D}${PTEST_PATH}

    # Strip build host paths from any installed Makefile
    for filename in ${PTEST_BUILD_HOST_FILES}; do
        for installed_ptest_file in $(find ${D}${PTEST_PATH} -type f -name $filename); do
            bbnote "Stripping host paths from: $installed_ptest_file"
            sed -e 's#${HOSTTOOLS_DIR}/*##g' \
                -e 's#${WORKDIR}/*=#.=#g' \
                -e 's#${WORKDIR}/*##g' \
                -i $installed_ptest_file
            if [ -n "${PTEST_BUILD_HOST_PATTERN}" ]; then
               sed -E '/${PTEST_BUILD_HOST_PATTERN}/d' \
                   -i $installed_ptest_file
            fi
        done
    done

    if [ "${PTEST_BINDIR}" == "1" ]; then
        install_ptest_bindir
    fi
}

PTEST_BINDIR_PATH="${D}${PTEST_PATH}/bin"

install_ptest_bindir() {
    # Create ${PTEST_PATH}/bin to create symlinks to the package's binaries
    # this way the path can be added to PATH and execute the binaries easier
    # from ptest-runner.
    bbdebug 1 "Generating PTEST's bin directory"
    binary_paths="${bindir} ${sbindir} ${base_bindir} ${base_sbindir}"
    mkdir -p ${PTEST_BINDIR_PATH}

    for path in ${binary_paths}; do
        for src in ${D}${path}/*; do
            binary=`basename ${src}`
            ln -s ${path}/${binary} ${PTEST_BINDIR_PATH}/${binary}
        done
    done
}

# This function needs to run after apply_update_alternative_renames because the
# aforementioned function will update the ALTERNATIVE_LINK_NAME flag. Append is
# used here to make this function to run as late as possible.
PACKAGE_PREPROCESS_FUNCS_append = "${@bb.utils.contains("PTEST_BINDIR", "1", " ptest_update_alternatives", "", d)}"

python ptest_update_alternatives() {
    """
    This function will fix the symlinks in the PTEST_BINDIR that
    were broken by the renaming of update-alternatives
    """

    if not bb.data.inherits_class('update-alternatives', d) \
           or not update_alternatives_enabled(d):
        return

    bb.note("Updating PTEST symlinks after the renaming of update-alternatives")

    ptest_pkgd_bindir = os.path.join(d.getVar("PKGD"),
                                     d.getVar("PTEST_PATH")[1:],
                                     "bin")
    links_dict = { os.path.join(ptest_pkgd_bindir, link):
                   os.readlink(os.path.join(ptest_pkgd_bindir, link))
                   for link in os.listdir(ptest_pkgd_bindir) }
    for filename, link in links_dict.items():
        alt_link = update_alternatives_get_alt_target(d, link)
        if alt_link:
            os.unlink(filename)
            os.symlink(alt_link, filename)
}

do_configure_ptest_base[dirs] = "${B}"
do_compile_ptest_base[dirs] = "${B}"
do_install_ptest_base[dirs] = "${B}"
do_install_ptest_base[cleandirs] = "${D}${PTEST_PATH}"

addtask configure_ptest_base after do_configure before do_compile
addtask compile_ptest_base   after do_compile   before do_install
addtask install_ptest_base   after do_install   before do_package do_populate_sysroot

python () {
    if not bb.data.inherits_class('native', d) and not bb.data.inherits_class('cross', d):
        d.setVarFlag('do_install_ptest_base', 'fakeroot', '1')
        d.setVarFlag('do_install_ptest_base', 'umask', '022')

    # Remove all '*ptest_base' tasks when ptest is not enabled
    if not(d.getVar('PTEST_ENABLED') == "1"):
        for i in ['do_configure_ptest_base', 'do_compile_ptest_base', 'do_install_ptest_base']:
            bb.build.deltask(i, d)
}
