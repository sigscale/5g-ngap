## Makefile.am
## vim: ts=3
##
## Process this file with automake to produce Makefile.in

modhtml = ngap.html \
			ngap_app.html \
			ngap_sup.html \
			ngap_endpoint_sup_sup.html \
			ngap_endpoint_sup.html \
			ngap_association_sup.html \
			ngap_context_sup.html \
			ngap_server.html \
			ngap_listen_fsm.html \
			ngap_association_fsm.html \
			ngap_context_fsm.html \
			ngap_codec.html

doc_DATA = overview.edoc $(modhtml) \
		modules-frame.html overview-summary.html \
		index.html stylesheet.css \
		sigscale-logo.png supervision.png

overview.edoc: overview.edoc-in
	sed -e 's!%VERSION%!$(VERSION)!' \
			-e 's!%DESCRIPTION%!$(PACKAGE)!' < $< > $@

%.html:$(top_srcdir)/src/%.erl	overview.edoc $(top_srcdir)/doc/supervision.edoc
	$(ERL) -noshell -run edoc_run application \
			"'$(PACKAGE_NAME)'" "'$(top_builddir)'" \
			'[{sort_functions,false},{private,true},{todo,true},{source_path,["$(top_srcdir)/src","$(top_builddir)/src"]},{subpackages,false},{def,{docsrc,"$(top_srcdir)/doc/{@?}"}}]'
	for i in `ls *.html`; do \
			sed -e 's!erlang logo!sigscale logo!' \
					-e 's!href=\"http://www.erlang.org/\"!href=\"http://www.sigscale.org/\"!' \
					-e 's!erlang.png!sigscale-logo.png!' $$i > $$i.tmp; \
			mv $$i.tmp $$i; \
	done
	-cp -n $(top_srcdir)/doc/sigscale-logo.png .
	-cp -n $(top_srcdir)/doc/supervision.png .

CLEANFILES = overview.edoc edoc-info index.html \
		modules-frame.html overview-summary.html packages-frame.html \
		stylesheet.css erlang.png sigscale-logo.png supervision.png \
		$(modhtml)

