## configure.ac ## vim: ts=3
##
## Process this file with autoconf to produce a configure script.
##
## Boilerplate:  standard boilerplate code
##
AC_INIT([ngap], [0.1.0], [issues@sigscale.org])
AC_COPYRIGHT([Copyright (c) 2020 SigScale Global Inc.])
AC_PREREQ(2.63)
AC_CONFIG_SRCDIR([src/ngap_app.erl])
AC_CONFIG_HEADERS([config.h])
AM_INIT_AUTOMAKE([-Wno-portability])

##
## Options:  control options to configure, support code for the options
##
AC_ARG_ENABLE([debug],
		[AS_HELP_STRING([--enable-debug], [enable debugging (default is no)])])


##
## Programs:  check for programs needed by the configure process,
##            the build process, or by one of the programs being built
##
AC_LANG_PUSH([Erlang])
AC_ERLANG_NEED_ERL
AC_ERLANG_NEED_ERLC
if test -z "${ERLCFLAGS}" ; then
	ERLCFLAGS="-W -v"
fi
if test "x$enable_debug" == xyes ; then
	ERLCFLAGS="$ERLCFLAGS +debug_info"
fi
AC_ERLANG_SUBST_LIB_DIR
if test -z "${ERLANG_INSTALL_LIB_DIR}" ; then
	ERLANG_INSTALL_LIB_DIR=$ERLANG_LIB_DIR
fi
AC_ERLANG_SUBST_ROOT_DIR
AC_PROG_MKDIR_P
AC_PROG_INSTALL
AC_PROG_LN_S
AC_ERLANG_SUBST_INSTALL_LIB_DIR
appdir=$ERLANG_INSTALL_LIB_DIR/$PACKAGE_NAME-$PACKAGE_VERSION
docdir=$ERLANG_INSTALL_LIB_DIR/$PACKAGE_NAME-$PACKAGE_VERSION/doc
erldir=$ERLANG_INSTALL_LIB_DIR/$PACKAGE_NAME-$PACKAGE_VERSION/src
beamdir=$ERLANG_INSTALL_LIB_DIR/$PACKAGE_NAME-$PACKAGE_VERSION/ebin
asndir=$ERLANG_INSTALL_LIB_DIR/$PACKAGE_NAME-$PACKAGE_VERSION/asn_src
AC_SUBST(appdir)
AC_SUBST(erldir)
AC_SUBST(beamdir)
AC_SUBST(asndir)


##
## Libraries:  check for libraries
##
AC_LANG_POP([Erlang])
AC_CHECK_LIB([sctp], [sctp_send], [],
		[AC_MSG_ERROR([libsctp was not found!])])
AC_LANG_PUSH([Erlang])
AC_ERLANG_SUBST_ERTS_VER
AC_ERLANG_CHECK_LIB([kernel], [], [AC_MSG_ERROR([kernel was not found!])])
AC_ERLANG_CHECK_LIB([stdlib],
		[if echo "$ERLANG_LIB_VER_stdlib\n3.5" | sort -CV;
		then AC_MSG_ERROR([>= stdlib-3.5 required!]); fi],
		[AC_MSG_ERROR([stdlib was not found!])])
AC_ERLANG_CHECK_LIB([asn1], [], [AC_MSG_ERROR([asn1 was not found!])])


##
## Headers:  check for header files
##


##
## Typedefs & Structures:  check for typedefs, structures,
##                         and compiler characteristics.
##


##
## Functions:  check for library functions
##


##
## Output:  create output files
##

AC_OUTPUT([Makefile src/Makefile ebin/Makefile doc/Makefile
		test/Makefile])

