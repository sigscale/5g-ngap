## Makefile.am
## vim: ts=3
##
## Process this file with automake to produce Makefile.in

testmods = ngap_api_SUITE \
		ngap_codec_SUITE \
		ngap_n2_SUITE \
		ngap_test_lib

check_DATA = .dialyzer_ok .common_test_ok

.dialyzer_ok:	$(addsuffix .beam, $(testmods))
	dialyzer --src $(top_srcdir)/src

%.beam:$(top_srcdir)/test/%.erl
	$(ERLC) -pa $(top_builddir)/ebin $(ERLCFLAGS) $<

.common_test_ok:	$(addsuffix .beam, $(testmods))
	@if [ ! -d log ]; then mkdir log; fi
	@if [ ! -f ct.cfg ]; then cp $(top_srcdir)/test/ct.cfg .; fi
	@if [ ! -f test.spec ]; then cp $(top_srcdir)/test/test.spec .; fi
	ct_run -no_auto_compile -pa $(top_builddir)/ebin -logdir log -config ct.cfg -spec test.spec -dir . -erl_args -noshell -sname $(LOGNAME)-ct

clean-local:
	-rm -r *.beam log/*

