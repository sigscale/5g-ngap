%%% ngap_n2_SUITE.erl
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
%%% Test suite for the 5GC N2 interface between 5G-AN and AMF in the
%%% {@link //ngap. ngap} application.
%%%
-module(ngap_n2_SUITE).
-copyright('Copyright (c) 2020 SigScale Global Inc.').

%% common_test required callbacks
-export([suite/0, sequences/0, all/0]).
-export([init_per_suite/1, end_per_suite/1]).
-export([init_per_testcase/2, end_per_testcase/2]).

%% ngap_n2_SUITE test exports
-export([ngsetup/0, ngsetup/1, transfer_error/0, transfer_error/1,
		abstract_error/0, abstract_error/1]).

-include_lib("common_test/include/ct.hrl").
-include_lib("kernel/include/inet_sctp.hrl").
-include("ngap_codec.hrl").

%%---------------------------------------------------------------------
%%  Test server callback functions
%%---------------------------------------------------------------------

-spec suite() -> DefaultData :: [tuple()].
%% Require variables and set default values for the suite.
%%
suite() ->
	[{timetrap, {minutes, 1}}].

-spec init_per_suite(Config :: [tuple()]) -> Config :: [tuple()].
%% Initiation before the whole suite.
%%
init_per_suite(Config) ->
	ok = ngap_test_lib:start(),
	Config.

-spec end_per_suite(Config :: [tuple()]) -> any().
%% Cleanup after the whole suite.
%%
end_per_suite(_Config) ->
	ok = ngap_test_lib:stop().

-spec init_per_testcase(TestCase :: atom(), Config :: [tuple()]) -> Config :: [tuple()].
%% Initiation before each test case.
%%
init_per_testcase(_TestCase, Config) ->
	Address = {127, 0,0, 1},
	Port =  rand:uniform(16383) + 49152,
	{ok, Endpoint} = ngap:start(Port, []),
	Options = [{active, once}, {reuseaddr, true},
			{sctp_events, #sctp_event_subscribe{adaptation_layer_event = true}},
			{sctp_default_send_param, #sctp_sndrcvinfo{ppid = 60}},
			{sctp_adaptation_layer, #sctp_setadaptation{adaptation_ind = 60}}],
	{ok, Socket} = gen_sctp:open(Options),
	{ok, #sctp_assoc_change{state = comm_up, assoc_id = Association}}
			= gen_sctp:connect(Socket, Address, Port, []),
	[{endpoint, Endpoint}, {address, Address}, {port, Port},
			{socket, Socket}, {association, Association} | Config].

-spec end_per_testcase(TestCase :: atom(), Config :: [tuple()]) -> any().
%% Cleanup after each test case.
%%
end_per_testcase(_TestCase, _Config) ->
	ok.

-spec sequences() -> Sequences :: [{SeqName :: atom(), Testcases :: [atom()]}].
%% Group test cases into a test sequence.
%%
sequences() ->
	[].

-spec all() -> TestCases :: [Case :: atom()].
%% Returns a list of all test cases in this test suite.
%%
all() ->
	[ngsetup, transfer_error, abstract_error].

%%---------------------------------------------------------------------
%%  Test cases
%%---------------------------------------------------------------------

ngsetup() ->
	[{userdata, [{doc, "NG Setup interface management request"}]}].

ngsetup(Config) ->
	Socket = ?config(socket, Config),
	Association = ?config(association, Config),
	Stream = 0,
	PlmnIdentity = plmn_identity(),
	NGSetupRequest = #'NGSetupRequest'{
			protocolIEs = [global_ran_node_id(PlmnIdentity),
			supported_ta_list(PlmnIdentity), paging_drx()]},
	InitiatingMessage = #'InitiatingMessage'{procedureCode = ?'id-NGSetup',
			criticality = reject, value = NGSetupRequest},
	{ok, RequestPDU} = ngap_codec:encode('NGAP-PDU',
			{initiatingMessage, InitiatingMessage}),
	ok = gen_sctp:send(Socket, Association, Stream, RequestPDU),
	{ok, {_, _, [#sctp_sndrcvinfo{assoc_id = Association, stream = Stream,
			ppid = 60}], ResponsePDU}} = sctp_response(Socket),
	{ok, {successfulOutcome, SO}} = ngap_codec:decode('NGAP-PDU', ResponsePDU),
	#'SuccessfulOutcome'{procedureCode = ?'id-NGSetup',
			criticality = reject, value = NGSetupResponse} = SO,
	#'NGSetupResponse'{protocolIEs = ResponseIEs} = NGSetupResponse,
	[#'ProtocolIE-Field'{id = ?'id-AMFName', value = _AMFName,
			criticality = reject} | T1] = ResponseIEs,
	[#'ProtocolIE-Field'{id = ?'id-ServedGUAMIList',
			value = _ServedGUAMIList, criticality = reject} | T2]  = T1,
	[#'ProtocolIE-Field'{id = ?'id-RelativeAMFCapacity',
			value = _RelativeAMFCapacity, criticality = ignore} | T3] = T2,
	[#'ProtocolIE-Field'{id= ?'id-PLMNSupportList',
			value = _PLMNSupportList, criticality = reject} | _T4] = T3.

transfer_error() ->
	[{userdata, [{doc, "Errror indication for bad PDU"}]}].

transfer_error(Config) ->
	Socket = ?config(socket, Config),
	Association = ?config(association, Config),
	Stream = 0,
	BogusPDU = <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>,
	ok = gen_sctp:send(Socket, Association, Stream, BogusPDU),
	{ok, {_, _, [#sctp_sndrcvinfo{}], ResponsePDU}} = sctp_response(Socket),
	{ok, {initiatingMessage, IM}} = ngap_codec:decode('NGAP-PDU', ResponsePDU),
	#'InitiatingMessage'{procedureCode = ?'id-ErrorIndication',
			criticality = ignore, value = ErrorIndication} = IM,
	#'ErrorIndication'{protocolIEs = RequestIEs} = ErrorIndication,
	[#'ProtocolIE-Field'{id = ?'id-Cause',
			value = {protocol, 'transfer-syntax-error'},
			criticality = ignore} | _T1] = RequestIEs.

abstract_error() ->
	[{userdata, [{doc, "Errror indication for missing mandatory IEs"}]}].

abstract_error(Config) ->
	Socket = ?config(socket, Config),
	Association = ?config(association, Config),
	Stream = 0,
	NGSetupRequest = #'NGSetupRequest'{protocolIEs = []},
	InitiatingMessage = #'InitiatingMessage'{procedureCode = ?'id-NGSetup',
			criticality = reject, value = NGSetupRequest},
	{ok, RequestPDU} = ngap_codec:encode('NGAP-PDU',
			{initiatingMessage, InitiatingMessage}),
	ok = gen_sctp:send(Socket, Association, Stream, RequestPDU),
	{ok, {_, _, [#sctp_sndrcvinfo{}], ResponsePDU}} = sctp_response(Socket),
	{ok, {unsuccessfulOutcome, UO}} = ngap_codec:decode('NGAP-PDU', ResponsePDU),
	#'UnsuccessfulOutcome'{procedureCode = ?'id-NGSetup',
			criticality = reject, value = NGSetupFailure} = UO,
	#'NGSetupFailure'{protocolIEs = FailureIEs} = NGSetupFailure,
	[#'ProtocolIE-Field'{id  = ?'id-Cause',
			value = {protocol, 'abstract-syntax-error-reject'},
			criticality = ignore} | _T1] = FailureIEs.

%%---------------------------------------------------------------------
%%  Internal functions
%%---------------------------------------------------------------------

plmn_identity() ->
	MCC = [0, 0, 1],
	MNC = [0, 0, 1],
	<< <<N:4>> || N <- MCC ++ MNC >>.

tac() ->
	TAC = rand:uniform(16777214),
	<<TAC:24>>.

gnbid(Length) when Length >= 22, Length =< 32 ->
	GnbID = rand:uniform(4294967296) - 1,
	<<GnbID:Length>>.

global_ran_node_id(PlmnIdentity) ->
	GNBIDLength = rand:uniform(11) + 21,
	GnbId = gnbid(GNBIDLength),
	GlobalGnbId = #'GlobalGNB-ID'{pLMNIdentity = PlmnIdentity,
			'gNB-ID' = {'gNB-ID', GnbId}},
	#'ProtocolIE-Field'{id = ?'id-GlobalRANNodeID',
			criticality = reject,
			value = {'globalGNB-ID', GlobalGnbId}}.

supported_ta_list(PlmnIdentity) ->
	SNSSAI = #'S-NSSAI'{'sST' = <<1:8>>},
	SliceSupport = #'SliceSupportItem'{'s-NSSAI' = SNSSAI},
	BroadcastPLMN =  #'BroadcastPLMNItem'{pLMNIdentity = PlmnIdentity,
			tAISliceSupportList = [SliceSupport]},
	SupportedTA = #'SupportedTAItem'{tAC = tac(),
			broadcastPLMNList = [BroadcastPLMN]},
	#'ProtocolIE-Field'{id = ?'id-SupportedTAList',
			criticality = reject, value = [SupportedTA]}.

paging_drx() ->
	#'ProtocolIE-Field'{id = ?'id-DefaultPagingDRX',
			criticality = ignore, value = v32}.

sctp_response(Socket) ->
	case gen_sctp:recv(Socket) of
		{ok, {_, _, [], #sctp_paddr_change{addr = {Address, Port},
				state = State, assoc_id = Association}}} ->
			ct:pal(?LOW_IMPORTANCE, "=SCTP Peer Address Change===~n"
					"~tstate: ~w~n~tsocket: ~w~n~taddress: ~w~n"
					"~tport: ~w~n~tassociation: ~w~n",
					[State, Socket, Address, Port, Association]),
			sctp_response(Socket);
		Other ->
			Other
	end.

