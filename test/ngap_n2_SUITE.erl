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
-export([ngsetup/0, ngsetup/1]).

-include_lib("common_test/include/ct.hrl").
-include_lib("kernel/include/inet_sctp.hrl").
-include_lib("ngap/include/ngap_codec.hrl").

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
	Config.

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
	[ngsetup].

%%---------------------------------------------------------------------
%%  Test cases
%%---------------------------------------------------------------------

ngsetup() ->
	[{userdata, [{doc, "NG Setup interface management request"}]}].

ngsetup(_Config) ->
	Port =  rand:uniform(16383) + 49152,
	{ok, _EP} = ngap:start({?MODULE, null}, Port, []),
	Options = [{active, once}, {reuseaddr, true},
			{sctp_events, #sctp_event_subscribe{adaptation_layer_event = true}},
			{sctp_default_send_param, #sctp_sndrcvinfo{ppid = 60}},
			{sctp_adaptation_layer, #sctp_setadaptation{adaptation_ind = 60}}],
	{ok, Socket} = gen_sctp:open(Options),
	{ok, #sctp_assoc_change{state = comm_up, assoc_id = Assoc}}
			= gen_sctp:connect(Socket, {127, 0,0, 1}, Port, []),
	NGSetupRequest = #'NGSetupRequest'{protocolIEs = []},
	InitiatingMessage = #'InitiatingMessage'{procedureCode = 21,
			criticality = reject, value = NGSetupRequest},
	{ok, PDU} = ngap_codec:encode('NGAP-PDU',
			{initiatingMessage, InitiatingMessage}),
	ok = gen_sctp:send(Socket, Assoc, 0, PDU).

%%---------------------------------------------------------------------
%%  Internal functions
%%---------------------------------------------------------------------

