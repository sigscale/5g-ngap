## Makefile.am
##
## Process this file with automake to produce Makefile.in

appdir = $(beamdir)
app_DATA = ngap.app
EXTRA_DIST = ngap.app

beam_DATA = ngap.beam \
		ngap_app.beam \
		ngap_sup.beam

%.beam:	$(top_builddir)/src/%.erl
	$(ERLC) $(ERLCFLAGS) $<

%.app:   %.app-in
	sed -e 's/%APP_NAME%/$(PACKAGE_NAME)/' \
			-e 's/%APP_VERSION%/$(PACKAGE_VERSION)/' < $< > $@ 

CLEANFILES = $(beam_DATA) $(app_DATA)

