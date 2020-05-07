%%% ngap_association_fsm.erl
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
%%% 	module implements an SCTP association socket handler in the
%%% 	{@link //ngap. ngap} application.
%%%
-module(ngap_association_fsm).
-copyright('Copyright (c) 2020 SigScale Global Inc.').

-behaviour(gen_statem).

%% export the ngap_association_fsm API
-export([]).

%% export the callbacks needed for gen_statem behaviour
-export([init/1, handle_event/4, callback_mode/0,
			terminate/3, code_change/4]).
%% export the callbacks for gen_statem states. 
-export([active/3]).

-include_lib("kernel/include/inet_sctp.hrl").

-type state() :: active.

-record(statedata,
		{ep_sup :: pid(),
		stream_sup :: undefined | pid(),
		endpoint :: pid(),
		socket :: gen_sctp:sctp_socket(),
		assoc_id :: gen_sctp:assoc_id(),
		callback :: {Module :: atom(), Function :: atom()},
		peer_addr :: inet:ip_address(),
		peer_port :: inet:port_number(),
		in_streams :: pos_integer(),
		out_streams :: pos_integer(),
		streams = #{} :: #{Stream :: non_neg_integer() =>  Fsm ::pid()}}).
-type statedata() :: #statedata{}.

%%----------------------------------------------------------------------
%%  The ngap_association_fsm API
%%----------------------------------------------------------------------

%%----------------------------------------------------------------------
%%  The ngap_association_fsm gen_statem callbacks
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
init([EpSup, Socket, PeerAddr, PeerPort,
		#sctp_assoc_change{assoc_id = Assoc,
		inbound_streams = InStreams, outbound_streams = OutStreams},
		Endpoint, Callback]) ->
	case inet:setopts(Socket, [{active, once}]) of
		ok ->
			process_flag(trap_exit, true),
			Data = #statedata{ep_sup = EpSup,
					socket = Socket, assoc_id = Assoc,
					peer_addr = PeerAddr, peer_port = PeerPort,
					in_streams = InStreams, out_streams = OutStreams,
					endpoint = Endpoint, callback = Callback},
			{ok, active, Data, 0};
		{error, Reason} ->
			{stop, Reason}
	end.

-spec active(EventType, EventContent, Data) -> Result
	when
		EventType :: gen_statem:event_type(),
		EventContent :: term(),
		Data :: statedata(),
		Result :: gen_statem:event_handler_result(state()).
%% @doc Handles events received in the <em>active</em> state.
%% @private
%%
active(timeout, _EventContent,
		#statedata{stream_sup = undefined} = Data) ->
	{next_state, active, get_stream_sup(Data)};
active(EventType, EventContent,
		#statedata{stream_sup = undefined} = Data) ->
	active(EventType, EventContent, get_stream_sup(Data));
active(info, {sctp, Socket, _FromAddr, _FromPort,
		{_AncData, #sctp_paddr_change{state = addr_confirmed,
		assoc_id = Assoc, addr = {PeerAddr, PeerPort}}}},
		#statedata{assoc_id = Assoc} = Data) ->
	ok = inet:setopts(Socket, [{active, once}]),
	NewData = Data#statedata{peer_addr = PeerAddr, peer_port = PeerPort},
	{next_state, active, NewData};
active(info, {sctp, Socket, _FromAddr, _FromPort,
		{_AncData, #sctp_adaptation_event{adaptation_ind = 60, assoc_id = Assoc}}},
		#statedata{socket = Socket, assoc_id = Assoc} = Data) ->
	ok = inet:setopts(Socket, [{active, once}]),
	{next_state, active, Data};
active(info, {sctp, Socket, _FromAddr, _FromPort,
		{[#sctp_sndrcvinfo{stream = Stream, ppid = 60, assoc_id = Assoc}], PDU}},
		#statedata{socket = Socket, endpoint = Endpoint, streams = Streams,
		assoc_id = Assoc} = Data) ->
	case maps:find(Stream, Streams) of
		{ok, StreamFsm} ->
			gen_statem:cast(StreamFsm, {ngap, Endpoint, Assoc, Stream, PDU}),
			{next_state, active, Data};
		error ->
			start_stream(Stream, active, PDU, Data)
	end;
active(info, {sctp, Socket, _FromAddr, _FromPort,
		{_AncData, #sctp_shutdown_event{assoc_id = Assoc}}},
		#statedata{socket = Socket, endpoint = Endpoint, assoc_id = Assoc} = Data) ->
	{stop, {shutdown, {{Endpoint, Assoc}, shutdown}}, Data};
active(info, {'EXIT', _Pid, {shutdown, {{Endpoint, Assoc, Stream}, _Reason}}},
		#statedata{endpoint = Endpoint, assoc_id = Assoc,
		streams = Streams} = Data) ->
	NewStreams = maps:remove(Stream, Streams),
	NewData = Data#statedata{streams = NewStreams},
	{next_state, active, NewData};
active(info, {'EXIT', Pid, shutdown}, #statedata{streams = Streams} = Data) ->
	Fdel = fun Fdel({Stream, P, _Iter}) when P ==  Pid ->
		       Stream;
		   Fdel({_Key, _Val, Iter}) ->
		       Fdel(maps:next(Iter));
		   Fdel(none) ->
		       none
	end,
	Iter = maps:iterator(Streams),
	Key = Fdel(maps:next(Iter)),
	NewStreams = maps:remove(Key, Streams),
	NewData = Data#statedata{streams = NewStreams},
	{next_state, active, NewData}.

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
terminate(_Reason, _State, _Data) ->
	ok.

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
get_stream_sup(#statedata{ep_sup = EpSup} = Data) ->
	Children = supervisor:which_children(EpSup),
	{_, StreamSup, _, _} = lists:keyfind(ngap_stream_sup, 1, Children),
	Data#statedata{stream_sup = StreamSup}.

%% @hidden
start_stream(Stream, State, PDU,
		#statedata{stream_sup = StreamSup,
		endpoint = Endpoint, socket = Socket,
		peer_addr = PeerAddr, peer_port = PeerPort,
		assoc_id = Assoc, streams = Streams} = Data) ->
	case supervisor:start_child(StreamSup,
			[[Endpoint, Socket, PeerAddr, PeerPort, Assoc, Stream], []]) of
		{ok, StreamFsm} ->
			link(StreamFsm),
			gen_statem:cast(StreamFsm, {ngap, Endpoint, Assoc, Stream, PDU}),
			NewStreams = Streams#{Stream => StreamFsm},
			NewData = Data#statedata{streams = NewStreams},
			ok = inet:setopts(Socket, [{active, once}]),
			{next_state, State, NewData};
		{error, Reason} ->
			{stop, {shutdown, {{Endpoint, Assoc}, Reason}}, Data}
	end.

