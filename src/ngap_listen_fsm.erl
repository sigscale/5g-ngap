%%% ngap_listen_fsm.erl
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
%%% @doc This {@link //stdlib/gen_statem. gen_statem} behaviour callback
%%% 	module implements a socket handler for incoming SCTP connections in the
%%% 	{@link //ngap. ngap} application.
%%%
-module(ngap_listen_fsm).
-copyright('Copyright (c) 2020 SigScale Global Inc.').

-behaviour(gen_statem).

%% export the ngap_listen_fsm API
-export([]).

%% export the callbacks needed for gen_statem behaviour
-export([init/1, handle_event/4, callback_mode/0,
			terminate/3, code_change/4]).
%% export the callbacks for gen_statem states. 
-export([listening/3]).

-include_lib("kernel/include/inet_sctp.hrl").

-type state() :: listening.

-record(statedata,
		{sup :: undefined | pid(),
		fsm_sup :: undefined | pid(),
		socket :: gen_sctp:sctp_socket(),
		options :: [tuple()],
		local_addr :: undefined | inet:ip_address(),
		local_port :: undefined | inet:port_number(),
		fsms = #{} :: #{Assoc :: gen_sctp:assoc_id() => Fsm :: pid()},
		callback :: {Module :: atom(), State :: term()}}).
-type statedata() :: #statedata{}.

%%----------------------------------------------------------------------
%%  The ngap_listen_fsm API
%%----------------------------------------------------------------------

%%----------------------------------------------------------------------
%%  The ngap_listen_fsm gen_statem callbacks
%%----------------------------------------------------------------------

-spec callback_mode() -> Result
	when
		Result :: gen_statem:callback_mode_result().
%% @doc Set the callback mode of the callback module.
%% @see //stdlib/gen_statem:callback_mode/0
%% @private
%%
callback_mode() ->
	state_functions.

-spec init(Args) -> Result
	when
		Args :: [term()],
		Result :: {ok, State, Data} | {ok, State, Data, Actions}
				| ignore | {stop, Reason},
		State :: state(),
		Data :: statedata(),
		Actions :: Action | [Action],
		Action :: gen_statem:action(),
		Reason :: term().
%% @doc Initialize the {@module} finite state machine.
%% @see //stdlib/gen_statem:init/1
%% @private
%%
init([Sup, Callback, Opts] = _Args) ->
	Options = [{active, once}, {reuseaddr, true},
			{sctp_events, #sctp_event_subscribe{adaptation_layer_event = true}},
			{sctp_default_send_param, #sctp_sndrcvinfo{ppid = 60}},
			{sctp_adaptation_layer, #sctp_setadaptation{adaptation_ind = 60}}
			| Opts],
	try
		case gen_sctp:open(Options) of
			{ok, Socket} ->
				case gen_sctp:listen(Socket, true) of
					ok ->
						case inet:sockname(Socket) of
							{ok, {LocalAddr, LocalPort}} ->
								process_flag(trap_exit, true),
								StateData = #statedata{sup = Sup,
										callback = Callback,
										options = Options,
										socket = Socket,
										local_addr = LocalAddr,
										local_port = LocalPort},
								{ok, listening, StateData, 0};
							{error, Reason} ->
								gen_sctp:close(Socket),
								throw(Reason)
						end;
					{error, Reason} ->
						gen_sctp:close(Socket),
						throw(Reason)
				end;
			{error, Reason} ->
				throw(Reason)
		end
	catch
		Reason1 ->
			error_logger:error_report(["Failed to open socket",
					{module, ?MODULE}, {error, Reason1}, {options, Options}]),
			{stop, Reason1}
	end.

-spec listening(EventType, EventContent, Data) -> Result
	when
		EventType :: gen_statem:event_type(),
		EventContent :: term(),
		Data :: statedata(),
		Result :: gen_statem:event_handler_result(state()).
%% @doc Handles events received in the <em>listening</em> state.
%% @private
%%
listening(timeout = _EventType, _EventContent,
		#statedata{fsm_sup = undefined} = Data) ->
   {next_state, listening, get_fsm_sup(Data)};
listening(EventType, EventContent,
		#statedata{fsm_sup = undefined} = Data) ->
	listening(EventType, EventContent, get_fsm_sup(Data));
listening(cast, {'M-SCTP_RELEASE', request, Ref, From},
		#statedata{socket = Socket} = Data) ->
	gen_server:cast(From,
			{'M-SCTP_RELEASE', confirm, Ref, gen_sctp:close(Socket)}),
	{stop, {shutdown, {self(), release}}, Data}.

-spec handle_event(EventType, EventContent, State, Data) -> Result
	when
		EventType :: gen_statem:event_type(),
		EventContent :: term(),
		State :: state(),
		Data :: statedata(),
		Result :: gen_statem:event_handler_result(State).
%% @doc Handles events received in the any state.
%% @private
%%
handle_event(_EventType, _EventContent, State, Data) ->
	{next_state, State, Data}.

-spec terminate(Reason, State, Data) -> any()
	when
		Reason :: normal | shutdown | {shutdown, term()} | term(),
      State :: state(),
		Data ::  statedata().
%% @doc Cleanup and exit.
%% @see //stdlib/gen_statem:terminate/3
%% @private
%%
terminate(_Reason, _State, #statedata{socket = Socket} = Data) ->
	case gen_sctp:close(Socket) of
		ok ->
			ok;
		{error, Reason1} ->
			error_logger:error_report(["Failed to close socket",
					{module, ?MODULE}, {socket, Socket},
					{error, Reason1}, {statedata, Data}])
	end.

-spec code_change(OldVsn, OldState, OldData, Extra) -> Result
	when
		OldVsn :: Version | {down, Version},
		Version ::  term(),
		OldState :: state(),
		OldData :: statedata(),
		Extra :: term(),
		Result :: {ok, NewState, NewData} |  Reason,
		NewState :: state(),
		NewData :: statedata(),
		Reason :: term().
%% @doc Update internal state data during a release upgrade&#047;downgrade.
%% @see //stdlib/gen_statem:code_change/3
%% @private
%%
code_change(_OldVsn, OldState, OldData, _Extra) ->
	{ok, OldState, OldData}.

%%----------------------------------------------------------------------
%%  internal functions
%%----------------------------------------------------------------------

%% @hidden
get_fsm_sup(#statedata{sup = Sup} = Data) ->
	Children = supervisor:which_children(Sup),
	{_, AssocSup, _, _} = lists:keyfind(ngap_association_sup, 1, Children),
	Data#statedata{fsm_sup = AssocSup}.

