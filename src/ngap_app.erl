%%% ngap_app.erl
%%% vim: ts=3
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @copyright 2020 SigScale Global Inc.
%%% @end
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%    http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc This {@link //stdlib/application. application} behaviour callback
%%% 	module starts and stops the {@link //ngap. ngap} application.
%%%
-module(ngap_app).
-copyright('Copyright (c) 2020 SigScale Global Inc.').

-behaviour(application).

%% callbacks needed for application behaviour
-export([start/2, stop/1, config_change/3]).
%% optional callbacks for application behaviour
-export([prep_stop/1, start_phase/3]).
%% public API
-export([install/0, install/1]).

-include("ngap.hrl").
-include_lib("kernel/include/logger.hrl").

-record(state, {}).

-define(WAITFORSCHEMA, 11000).
-define(WAITFORTABLES, 11000).

%%----------------------------------------------------------------------
%% The ngap_app aplication callbacks
%%----------------------------------------------------------------------

-type start_type() :: normal | {takeover, node()} | {failover, node()}.
-spec start(StartType, StartArgs) -> Result
	when
		StartType :: start_type(),
		StartArgs :: term(),
		Result :: {'ok', pid()} | {'ok', pid(), State} | {'error', Reason},
		State :: #state{},
		Reason :: term().
%% @doc Starts the application processes.
%% @see //kernel/application:start/1
%% @see //kernel/application:start/2
%%
start(normal = _StartType, _Args) ->
	Tables = [ue_conection],
	case mnesia:wait_for_tables(Tables, 60000) of
		ok ->
			supervisor:start_link(ngap_sup, []);
		{timeout, BadTabList} ->
			case force(BadTabList) of
				ok ->
					supervisor:start_link(ngap_sup, []);
				{error, Reason} ->
					?LOG_ERROR("ngap application failed to start~n"
							"reason: ~w~n", [Reason]),
					{error, Reason}
			end;
		{error, Reason} ->
			{error, Reason}
	end.

-spec install() -> Result
	when
		Result :: {ok, Tables},
		Tables :: [atom()].
%% @equiv install([node() | nodes()])
install() ->
	Nodes = [node() | nodes()],
	install(Nodes).

-spec install(Nodes) -> Result
	when
		Nodes :: [node()],
		Result :: {ok, Tables},
		Tables :: [atom()].
%% @doc Initialize AMF tables.
%%
%% 	`Nodes' is a list of the nodes where tables will be replicated.
%%
%% 	If {@link //mnesia. mnesia} is not running an attempt
%% 	will be made to create a schema on all available nodes.
%% 	If a schema already exists on any node
%% 	{@link //mnesia. mnesia} will be started on all nodes
%% 	using the existing schema.
%%
%% @private
%%
install(Nodes) when is_list(Nodes) ->
	case mnesia:system_info(is_running) of
		no ->
			case mnesia:create_schema(Nodes) of
				ok ->
					?LOG_INFO("Created mnesia schema~n"
							"nodes: ~w~n", [Nodes]),
					install1(Nodes);
				{error, Reason} ->
					?LOG_ERROR("Failed to create schema~n"
							"~p~nnodes: ~w~n",
							[mnesia:error_description(Reason), Nodes]),
					{error, Reason}
			end;
		_ ->
			install2(Nodes)
	end.
%% @hidden
install1([Node] = Nodes) when Node == node() ->
	case mnesia:start() of
		ok ->
			?LOG_INFO("Started mnesia~n"),
			install2(Nodes);
		{error, Reason} ->
			?LOG_ERROR("~p~n", [mnesia:error_description(Reason)]),
			{error, Reason}
	end;
install1(Nodes) ->
	case rpc:multicall(Nodes, mnesia, start, [], 60000) of
		{Results, []} ->
			F = fun(ok) ->
						false;
					(_) ->
						true
			end,
			case lists:filter(F, Results) of
				[] ->
					?LOG_INFO("Started mnesia on all nodes~n"
							"nodes: ~w~n", [Nodes]),
					install2(Nodes);
				NotOKs ->
					?LOG_ERROR("Failed to start mnesia on all nodes~n"
							"nodes: ~w~nerrors: ~w~n", [Nodes, NotOKs]),
					{error, NotOKs}
			end;
		{Results, BadNodes} ->
			?LOG_ERROR("Failed to start mnesia on all nodes~n"
					"nodes: ~w~nresults: ~w~nbad nodes: ~w~n",
					[Nodes, Results, BadNodes]),
			{error, {Results, BadNodes}}
	end.
%% @hidden
install2(Nodes) ->
	case mnesia:wait_for_tables([schema], ?WAITFORSCHEMA) of
		ok ->
			install3(Nodes, []);
		{error, Reason} ->
			?LOG_ERROR("~p~n", [mnesia:error_description(Reason)]),
			{error, Reason};
		{timeout, Tables} ->
			?LOG_ERROR("Timeout waiting for tables~n",
					"tables: ~w~n", [Tables]),
			{error, timeout}
	end.
%% @hidden
install3(Nodes, Acc) ->
	case mnesia:create_table(ue_connection,
			[{type, ordered_set}, {ram_copies, Nodes},
			{attributes, record_info(fields, ue_connection)},
			{index, [#ue_connection.imsi]}]) of
		{atomic, ok} ->
			?LOG_INFO("Created new UE connection table.~n"),
			install4(Nodes, [ue_connection | Acc]);
		{aborted, {not_active, _, Node} = Reason} ->
			?LOG_ERROR("Mnesia not started on node: ~w~n", [Node]),
			{error, Reason};
		{aborted, {already_exists, ue_connection}} ->
			?LOG_INFO("Found existing UE connection table.~n"),
			install4(Nodes, [ue_connection | Acc]);
		{aborted, Reason} ->
			?LOG_ERROR("~p~n", [mnesia:error_description(Reason)]),
			{error, Reason}
	end.
%% @hidden
install4(_Nodes, Acc) ->
	{ok, lists:reverse(Acc)}.

%%----------------------------------------------------------------------
%% The ngap_app private API
%%----------------------------------------------------------------------

-spec start_phase(Phase, StartType, PhaseArgs) -> Result
	when
		Phase :: atom(),
		StartType :: start_type(),
		PhaseArgs :: term(),
		Result :: ok | {error, Reason},
		Reason :: term().
%% @doc Called for each start phase in the application and included
%% 	applications.
%% @see //kernel/app
%%
start_phase(_Phase, _StartType, _PhaseArgs) ->
	ok.

-spec prep_stop(State) -> #state{}
	when
		State :: #state{}.
%% @doc Called when the application is about to be shut down,
%% 	before any processes are terminated.
%% @see //kernel/application:stop/1
%%
prep_stop(State) ->
	State.

-spec stop(State) -> any()
	when
		State :: #state{}.
%% @doc Called after the application has stopped to clean up.
%%
stop(_State) ->
	ok.

-spec config_change(Changed, New, Removed) -> ok
	when
		Changed:: [{Par, Val}],
		New :: [{Par, Val}],
		Removed :: [Par],
		Par :: atom(),
		Val :: atom().
%% @doc Called after a code replacement, if there are any
%% 	changes to the configuration parameters.
%%
config_change(_Changed, _New, _Removed) ->
	ok.

%%----------------------------------------------------------------------
%% internal functions
%%----------------------------------------------------------------------

-spec force(Tables) -> Result
	when
		Tables :: [TableName],
		Result :: ok | {error, Reason},
		TableName :: atom(),
		Reason :: term().
%% @doc Try to force load bad tables.
force([H | T]) ->
	case mnesia:force_load_table(H) of
		yes ->
			force(T);
		ErrorDescription ->
			{error, ErrorDescription}
	end;
force([]) ->
	ok.

