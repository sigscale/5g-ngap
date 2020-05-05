%%% ngap_test_lib.erl
%%% vim: ts=3
%%%
-module(ngap_test_lib).

-export([start/0, stop/0]).

start() ->
	start([asn1, ngap]).

start([H | T]) ->
	case application:start(H) of
		ok  ->
			start(T);
		{error, {already_started, H}} ->
			start(T);
		{error, Reason} ->
			{error, Reason}
	end;
start([]) ->
	ok.

stop() ->
	application:stop(ngap).

