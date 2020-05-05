%%% ngap_server.erl
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
%%% @doc This {@link //stdlib/gen_server. gen_server} behaviour callback
%%% 	module implements a service access point (SAP) for the public API of the
%%% 	{@link //ngap. ngap} application.
%%%
-module(ngap_server).
-copyright('Copyright (c) 2020 SigScale Global Inc.').

-behaviour(gen_server).

%% export the ngap_server API
-export([start/2, stop/1]).

%% export the callbacks needed for gen_server behaviour
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
			terminate/2, code_change/3]).

-include_lib("kernel/include/inet_sctp.hrl").

-record(state,
		{sup :: pid(),
		ep_sup_sup :: undefined | pid(),
		eps = #{} :: #{EP :: pid() => USAP :: pid()},
		fsms = #{} :: #{{EP :: pid(),
				Assoc :: gen_sctp:assoc_id()} => Fsm :: pid()},
		reqs = #{} :: #{Ref :: reference() => From :: pid()}}).
-type state() :: #state{}.

%%----------------------------------------------------------------------
%%  The ngap_server API
%%----------------------------------------------------------------------

-spec start(Callback, Options) -> Result
	when
		Callback :: {Module :: atom(), Function :: atom()},
		Options :: [term()],
		Result :: {ok, EP} | {error, Reason},
		EP :: pid(),
		Reason :: term().
%% @doc Open a new server end point (`EP').
%% @private
start(Callback, Options) when is_list(Options) ->
	gen_server:call(ngap, {start, Callback, Options}).

-spec stop(EP :: pid()) -> ok | {error, Reason :: term()}.
%% @doc Close a previously opened end point (`EP').
%% @private
stop(EP) ->
	gen_server:call(ngap, {stop, EP}).

%%----------------------------------------------------------------------
%%  The ngap_server gen_server callbacks
%%----------------------------------------------------------------------

-spec init(Args) -> Result
	when
		Args :: [term()],
		Result :: {ok, State :: state()}
			| {ok, State :: state(), Timeout :: timeout()}
			| {stop, Reason :: term()} | ignore.
%% @doc Initialize the {@module} server.
%% @see //stdlib/gen_server:init/1
%% @private
%%
init([Sup] = _Args) ->
	process_flag(trap_exit, true),
	{ok, #state{sup = Sup}, 0}.

-spec handle_call(Request, From, State) -> Result
	when
		Request :: term(),
		From :: {pid(), Tag :: any()},
		State :: state(),
		Result :: {reply, Reply :: term(), NewState :: state()}
			| {reply, Reply :: term(), NewState :: state(), timeout() | hibernate}
			| {noreply, NewState :: state()}
			| {noreply, NewState :: state(), timeout() | hibernate}
			| {stop, Reason :: term(), Reply :: term(), NewState :: state()}
			| {stop, Reason :: term(), NewState :: state()}.
%% @doc Handle a request sent using {@link //stdlib/gen_server:call/2.
%% 	gen_server:call/2,3} or {@link //stdlib/gen_server:multi_call/2.
%% 	gen_server:multi_call/2,3,4}.
%% @see //stdlib/gen_server:handle_call/3
%% @private
%%
handle_call({start, Callback, Options}, {USAP, _Tag} = _From,
		#state{ep_sup_sup = EPSupSup, eps = Endpoints} = State) ->
	case supervisor:start_child(EPSupSup, [[Callback, Options]]) of
		{ok, EndpointSup} ->
			Find = fun F([{ngap_listen_fsm, EP, _, _} | _]) ->
						EP;
					F([_ | T]) ->
						F(T)
			end,
			EP = Find(supervisor:which_children(EndpointSup)),
			link(EP),
			NewEndpoints = Endpoints#{EP => USAP},
			NewState = State#state{eps = NewEndpoints},
			{reply, {ok, EP}, NewState};
		{error, Reason} ->
			{reply, {error, Reason}, State}
	end;
handle_call({stop, EP}, From, #state{reqs = Reqs} = State) when is_pid(EP) ->
	Ref = make_ref(),
	gen_statem:cast(EP, {'M-SCTP_RELEASE', request, Ref, self()}),
	NewReqs = Reqs#{Ref => From},
	NewState = State#state{reqs = NewReqs},
	{noreply, NewState};
handle_call({'M-SCTP_RELEASE', request, Endpoint, Assoc},
		From, #state{reqs = Reqs, fsms = Fsms} = State) ->
	case maps:find({Endpoint, Assoc}, Fsms) of
		{ok, Fsm} ->
			Ref = make_ref(),
			gen_statem:call(Fsm, {'M-SCTP_RELEASE', request, Ref, self()}),
			NewReqs = Reqs#{Ref => From},
			NewState = State#state{reqs = NewReqs},
			{noreply, NewState};
		error ->
			{reply, {error, invalid_assoc}, State}
	end.

-spec handle_cast(Request, State) -> Result
	when
		Request :: term(),
		State :: state(),
		Result :: {noreply, NewState :: state()}
			| {noreply, NewState :: state(), timeout() | hibernate}
			| {stop, Reason :: term(), NewState :: state()}.
%% @doc Handle a request sent using {@link //stdlib/gen_server:cast/2.
%% 	gen_server:cast/2} or {@link //stdlib/gen_server:abcast/2.
%% 	gen_server:abcast/2,3}.
%% @see //stdlib/gen_server:handle_cast/2
%% @private
%%
handle_cast({'M-SCTP_RELEASE', confirm, Ref, Result},
		#state{reqs = Reqs} = State) ->
	case maps:find(Ref, Reqs) of
		{ok, From} ->
			gen_server:reply(From, Result),
			NewReqs = maps:remove(Ref, Reqs),
			NewState = State#state{reqs = NewReqs},
			{noreply, NewState};
		error ->
			{noreply, State}
	end.

-spec handle_info(Info, State) -> Result
	when
		Info :: timeout | term(),
		State:: state(),
		Result :: {noreply, NewState :: state()}
			| {noreply, NewState :: state(), timeout() | hibernate}
			| {stop, Reason :: term(), NewState :: state()}.
%% @doc Handle a received message.
%% @see //stdlib/gen_server:handle_info/2
%% @private
%%
handle_info(timeout,
		#state{sup = Sup, ep_sup_sup = undefined} = State) ->
	Children = supervisor:which_children(Sup),
	{_, EpSupSup, _, _} = lists:keyfind(ngap_endpoint_sup_sup, 1, Children),
	{noreply, State#state{ep_sup_sup = EpSupSup}};
handle_info({'EXIT', EP, {shutdown, {EP, _Reason}}},
		#state{eps = EPs} = State) ->
	NewEPs = maps:remove(EP, EPs),
	NewState = State#state{eps = NewEPs},
	{noreply, NewState};
handle_info({'EXIT', _Pid, {shutdown, {{EP, Assoc}, _Reason}}},
		#state{fsms = Fsms} = State) ->
	NewFsms = maps:remove({EP, Assoc}, Fsms),
	NewState = State#state{fsms = NewFsms},
	{noreply, NewState};
handle_info({'EXIT', Pid, _Reason},
		#state{eps = EPs, fsms = Fsms, reqs = Reqs} = State) ->
	case maps:is_key(Pid, EPs) of
		true ->
			NewState = State#state{eps = maps:remove(Pid, EPs)},
			{noreply, NewState};
		false ->
			Fdel1 = fun F({Key, Fsm, _Iter}) when Fsm ==  Pid ->
						Key;
					F({_Key, _Val, Iter}) ->
						F(maps:next(Iter));
					F(none) ->
						none
			end,
			Iter1 = maps:iterator(Fsms),
			case Fdel1(maps:next(Iter1)) of
				none ->
					Fdel2 = fun F({Key, {P, _},  _Iter}) when P ==  Pid ->
								Key;
							F({_Key, _Val, Iter}) ->
								F(maps:next(Iter));
							F(none) ->
								none
					end,
					Iter2 = maps:iterator(Reqs),
					case Fdel2(maps:next(Iter2)) of
						none ->
							{noreply, State};
						Key2 ->
							NewReqs = maps:remove(Key2, Reqs),
							NewState = State#state{reqs = NewReqs},
							{noreply, NewState}
					end;
				Key ->
					NewFsms = maps:remove(Key, Fsms),
					NewState = State#state{fsms = NewFsms},
					{noreply, NewState}
			end
	end.

-spec terminate(Reason, State) -> any()
	when
		Reason :: normal | shutdown | {shutdown, term()} | term(),
      State::state().
%% @doc Cleanup and exit.
%% @see //stdlib/gen_server:terminate/3
%% @private
%%
terminate(normal = _Reason, _State) ->
	ok;
terminate(shutdown = _Reason, _State) ->
	ok;
terminate({shutdown, _} = _Reason, _State) ->
	ok;
terminate(Reason, State) ->
	error_logger:error_report(["Shutdown",
			{module, ?MODULE}, {pid, self()},
			{reason, Reason}, {state, State}]).

-spec code_change(OldVsn, State, Extra) -> Result
	when
		OldVsn :: term() | {down, term()},
		State :: state(),
		Extra :: term(),
		Result :: {ok, NewState :: state()} | {error, Reason :: term()}.
%% @doc Update internal state data during a release upgrade&#047;downgrade.
%% @see //stdlib/gen_server:code_change/3
%% @private
%%
code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%%----------------------------------------------------------------------
%%  internal functions
%%----------------------------------------------------------------------

