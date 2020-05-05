%%% ngap.erl
%%% vim: ts=3
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @copyright 2020 SigScale Global Inc.
%%% @end
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc This library module implements the public API for the
%%%   {@link //ngap. ngap} application.
%%%
-module(ngap).
-copyright('Copyright (c) 2020 SigScale Global Inc.').

%% export the ngap public API
-export([start/1, start/3, stop/1]).

%%----------------------------------------------------------------------
%%  The ngap public API
%%----------------------------------------------------------------------

-spec start(Callback) -> Result
	when
		Callback :: {Module :: atom(), Function :: atom()},
		Result :: {ok, Endpoint} | {error, Reason},
		Endpoint :: pid(),
		Reason :: term().
%% @equiv start(Callback, 0, [])
start(Callback) ->
	start(Callback, 0, []).

-spec start(Callback, Port, Options) -> Result
	when
		Port :: inet:port_number(),
		Options :: [term()],
		Callback :: {Module :: atom(), Function :: atom()},
		Result :: {ok, Endpoint} | {error, Reason},
		Endpoint :: pid(),
		Reason :: term().
%% @doc Start an NGAP service on a new SCTP endpoint.
start({Module, Function} = Callback, Port, Options)
		when is_atom(Module), is_atom(Function),
		is_integer(Port), is_list(Options) ->
	ngap_server:start(Callback, [{port, Port} | Options]).

-spec stop(Endpoint:: pid()) -> ok | {error, Reason :: term()}.
%% @doc Close a previously opened endpoint.
stop(Endpoint) when is_pid(Endpoint) ->
	ngap_server:stop(Endpoint).

%%----------------------------------------------------------------------
%%  internal functions
%%----------------------------------------------------------------------

