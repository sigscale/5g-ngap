%%% ngap_codec_SUITE.erl
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
%%% Test suite for the ASN.1 CODEC of the
%%% {@link //ngap. ngap} application.
%%%
-module(ngap_codec_SUITE).
-copyright('Copyright (c) 2020 SigScale Global Inc.').

%% common_test required callbacks
-export([suite/0, sequences/0, all/0]).
-export([init_per_suite/1, end_per_suite/1]).
-export([init_per_testcase/2, end_per_testcase/2]).

%% ngap_codec_SUITE test exports
-export([encode/0, encode/1, decode/0, decode/1]).

-include_lib("common_test/include/ct.hrl").
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
	[encode, decode].

%%---------------------------------------------------------------------
%%  Test cases
%%---------------------------------------------------------------------

encode() ->
	[{userdata, [{doc, "Encode an NGAP protocol data unit (PDU)"}]}].

encode(_Config) ->
	NGSetupRequest = #'NGSetupRequest'{protocolIEs = []},
	InitiatingMessage = #'InitiatingMessage'{procedureCode = 21,
			criticality = reject, value = NGSetupRequest},
	{ok, PDU} = ngap_codec:encode('NGAP-PDU',
			{initiatingMessage, InitiatingMessage}),
	<<160,12,128,1,21,129,1,0,130,4,48,2,160,0>> = PDU.

decode() ->
	[{userdata, [{doc, "Decode an NGAP protocol data unit (PDU)"}]}].

decode(_Config) ->
	PDU = <<160,12,128,1,21,129,1,0,130,4,48,2,160,0>>,
	{ok, {initiatingMessage, IM}} = ngap_codec:decode('NGAP-PDU', PDU),
	#'InitiatingMessage'{procedureCode = 21,
			criticality = reject, value = NGSetupRequest} = IM,
	#'NGSetupRequest'{protocolIEs = []} = NGSetupRequest.

%%---------------------------------------------------------------------
%%  Internal functions
%%---------------------------------------------------------------------

