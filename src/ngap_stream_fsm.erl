%%% ngap_stream_fsm.erl
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
%%% 	module implements an SCTP stream handler in the
%%% 	{@link //ngap. ngap} application.
%%%
-module(ngap_stream_fsm).
-copyright('Copyright (c) 2020 SigScale Global Inc.').

-behaviour(gen_statem).

%% export the ngap_stream_fsm API
-export([]).

%% export the callbacks needed for gen_statem behaviour
-export([init/1, handle_event/4, callback_mode/0,
			terminate/3, code_change/4]).
%% export the callbacks for gen_statem states. 
-export([active/3]).

-include_lib("kernel/include/inet_sctp.hrl").
-include("ngap_codec.hrl").

-type state() :: active.

-record(statedata,
		{endpoint :: pid(),
		socket :: gen_sctp:sctp_socket(),
		peer_addr :: inet:ip_address(),
		peer_port :: inet:port_number(),
		assoc_id :: gen_sctp:assoc_id(),
		stream :: non_neg_integer()}).
-type statedata() :: #statedata{}.

%%----------------------------------------------------------------------
%%  The ngap_stream_fsm API
%%----------------------------------------------------------------------

%%----------------------------------------------------------------------
%%  The ngap_stream_fsm gen_statem callbacks
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
init([Endpoint, Socket, PeerAddr, PeerPort, Assoc, Stream]) ->
	case inet:setopts(Socket, [{active, once}]) of
		ok ->
			process_flag(trap_exit, true),
			Data = #statedata{socket = Socket, assoc_id = Assoc,
					peer_addr = PeerAddr, peer_port = PeerPort,
					stream = Stream, endpoint = Endpoint},
			{ok, active, Data};
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
active(cast, {ngap, Endpoint, Assoc, Stream, PDU},
		#statedata{endpoint = Endpoint, socket = Socket,
		assoc_id = Assoc, stream = Stream} = Data) ->
	case ngap_codec:decode('NGAP-PDU', PDU) of
		{ok, {initiatingMessage, InitiatingMessage}} ->
			initiating(InitiatingMessage, Data);
		{ok, {successfulOutcome, SuccessfulOutcome}} ->
			successful(SuccessfulOutcome, Data);
		{ok, {unsuccessfulOutcome, UnsuccessfulOutcome}} ->
			unsuccessful(UnsuccessfulOutcome, Data);
		_ ->
			Cause = {protocol, 'transfer-syntax-error'},
			CauseIE = #'ProtocolIE-Field'{id = ?'id-Cause',
					criticality = ignore, value = Cause},
			ErrorIndication = #'ErrorIndication'{
					% @todo add criticality diagnostics
					protocolIEs = [CauseIE]},
			InitiatingMessage = #'InitiatingMessage'{
					procedureCode = ?'id-ErrorIndication',
					criticality = ignore, value = ErrorIndication},
			{ok, ResponsePDU} = ngap_codec:encode('NGAP-PDU',
					{initiatingMessage, InitiatingMessage}),
			ok = gen_sctp:send(Socket, Assoc, Stream, ResponsePDU),
			{next_state, active, Data}
	end;
active(info, {'EXIT', _Pid, {shutdown, {{Endpoint, Assoc}, shutdown}}},
		#statedata{endpoint = Endpoint, assoc_id = Assoc,
		stream = Stream} = Data) ->
	{stop, {shutdown, {{Endpoint, Assoc, Stream}, shutdown}}, Data}.

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
initiating(#'InitiatingMessage'{procedureCode = ?'id-NGSetup',
		criticality = reject,
		value = #'NGSetupRequest'{protocolIEs = RequestIEs}},
		#statedata{socket = Socket, assoc_id = Assoc,
		stream = Stream} = Data) ->
	try
		#'ProtocolIE-Field'{value = _GlobalRANNodeID} = lists:keyfind(
				?'id-GlobalRANNodeID', #'ProtocolIE-Field'.id, RequestIEs),
		#'ProtocolIE-Field'{value = SupportedTAList} = lists:keyfind(
				?'id-SupportedTAList', #'ProtocolIE-Field'.id, RequestIEs),
		#'ProtocolIE-Field'{value = _DefaultPagingDRX} = lists:keyfind(
				?'id-DefaultPagingDRX', #'ProtocolIE-Field'.id, RequestIEs),
		SupportedTAList
	of
		TAs ->
			{ok, AmfName} = application:get_env(name),
			AMFNameIE = #'ProtocolIE-Field'{id = ?'id-AMFName',
						criticality = reject, value = AmfName},
			{ok, GUAMIs} = application:get_env(guami),
			F = fun(<<AMFPlmn:3/bytes, AMFRegion:1/bytes,
						AMFSet:10/bits, AMFPointer:6/bits>>) ->
					#'ServedGUAMIItem'{gUAMI = #'GUAMI'{pLMNIdentity = AMFPlmn,
					aMFRegionID = AMFRegion, aMFSetID = AMFSet,
					aMFPointer = AMFPointer}}
			end,
			ServedGUAMIIE = #'ProtocolIE-Field'{id = ?'id-ServedGUAMIList',
					criticality = reject,
					value = lists:map(F, GUAMIs)},
			{ok, Capacity} = application:get_env(capacity),
			CapacityIE = #'ProtocolIE-Field'{id = ?'id-RelativeAMFCapacity',
						criticality = ignore, value = Capacity},
			BroadcastPLMNs = lists:flatten([B ||
					#'SupportedTAItem'{broadcastPLMNList = B} <- TAs]),
			{ok, AmfPlmns} = application:get_env(plmn),
			PLMNSupportList = plmn_support(AmfPlmns, BroadcastPLMNs),
			PLMNSupportIE = #'ProtocolIE-Field'{id = ?'id-PLMNSupportList',
						criticality = reject, value = PLMNSupportList},
			NGSetupResponse = #'NGSetupResponse'{protocolIEs
					= [AMFNameIE, ServedGUAMIIE, CapacityIE, PLMNSupportIE]},
			SuccessfulOutcome = #'SuccessfulOutcome'{
					procedureCode = ?'id-NGSetup',
					criticality = reject, value = NGSetupResponse},
			{ok, ResponsePDU} = ngap_codec:encode('NGAP-PDU',
					{successfulOutcome, SuccessfulOutcome}),
			ok = gen_sctp:send(Socket, Assoc, Stream, ResponsePDU),
			{next_state, active, Data}
	catch
		_:_Reason ->
			Cause = {protocol, 'abstract-syntax-error-reject'},
			CauseIE = #'ProtocolIE-Field'{id = ?'id-Cause',
					criticality = ignore, value = Cause},
			NGSetupFailure = #'NGSetupFailure'{protocolIEs = [CauseIE]},
			UnsuccessfulOutcome = #'UnsuccessfulOutcome'{
					procedureCode = ?'id-NGSetup',
					% @todo add criticality diagnostics
					criticality = reject, value = NGSetupFailure},
			{ok, FailurePDU} = ngap_codec:encode('NGAP-PDU',
					{unsuccessfulOutcome, UnsuccessfulOutcome}),
			ok = gen_sctp:send(Socket, Assoc, Stream, FailurePDU),
			{next_state, active, Data}
	end.

%% @hidden
successful(SuccessfulOutcome, Data) ->
	{next_state, active, Data}.

%% @hidden
unsuccessful(UnsuccessfulOutcome, Data) ->
	{next_state, active, Data}.

-spec plmn_support(AmfPlmns, AnPlmns) -> PlmnSupport
	when
		AmfPlmns :: [{PLMNIdentity :: binary(), [SNSSAI :: binary()]}],
		AnPlmns :: [#'BroadcastPLMNItem'{}],
		PlmnSupport :: [#'PLMNSupportItem'{}].
%% @doc Return the intersection of AN and AMF PLMN lists.
%% @private
plmn_support(AmfPlmns, AnPlmns)
		when length(AmfPlmns) =< ?maxnoofBPLMNs,
		length(AnPlmns) =< ?maxnoofBPLMNs->
	plmn_support(AmfPlmns, AnPlmns, []).
%% @hidden
plmn_support([{PLMNIdentity, SNSSAIs} | T] = _AmfPlmns, AnPlmns, Acc) ->
	case lists:keymember(PLMNIdentity,
			#'BroadcastPLMNItem'.pLMNIdentity, AnPlmns) of
		true ->
			F = fun(<<SST:1/bytes>>) ->
						#'SliceSupportItem'{'s-NSSAI'
								= #'S-NSSAI'{sST = SST}};
					(<<SST:1/bytes, SD:3/bytes>>) ->
						#'SliceSupportItem'{'s-NSSAI'
								= #'S-NSSAI'{sST = SST, sD = SD}}
			end,
			PLMNSupportItem = #'PLMNSupportItem'{pLMNIdentity = PLMNIdentity,
					sliceSupportList = lists:map(F, SNSSAIs)},
			plmn_support(T, AnPlmns, [PLMNSupportItem | Acc]);
		false ->
			plmn_support(T, AnPlmns, Acc)
	end;
plmn_support([], _, Acc) ->
	lists:reverse(Acc).

