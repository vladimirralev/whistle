%%%-------------------------------------------------------------------
%%% @author James Aimonetti <james@2600hz.com>
%%% @copyright (C) 2010, James Aimonetti
%%% @doc
%%% Track statistics for a client requester
%%% @end
%%% Created :  4 Aug 2010 by James Aimonetti <james@2600hz.com>
%%%-------------------------------------------------------------------
-module(client_stats).

-behaviour(gen_server).

%% API
-export([start_link/0, req_callid/1, req_cmd/2]).
-export([resp_callid/1, resp_evt/2]).
-export([link_reqid_callid/2]).

-export([get_report/0, get_summary/0, reset/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-record(state, {events=[], links=[]}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

link_reqid_callid(ReqId, CallId) ->
    gen_server:cast(?MODULE, {link, ReqId, CallId}).

req_callid(ReqId) ->
    gen_server:cast(?MODULE, {start, ReqId}),
    gen_server:cast(?MODULE, {req_callid, ReqId}).

req_cmd(ReqId, Cmd) ->
    gen_server:cast(?MODULE, {{req_cmd, Cmd}, ReqId}).

resp_callid(ReqId) ->
    gen_server:cast(?MODULE, {resp_callid, ReqId}).

resp_evt(ReqId, Evt) ->
    gen_server:cast(?MODULE, {{resp_evt, Evt}, ReqId}).

get_report() ->
    gen_server:call(?MODULE, get_report).

get_summary() ->
    gen_server:call(?MODULE, get_summary).

reset() ->
    gen_server:call(?MODULE, reset).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(reset, _From, _State) ->
    {reply, ok, #state{}};
handle_call(get_report, _From, #state{events=Evts, links=Links}=State) ->
    {reply, generate_report(Evts, Links), State};
handle_call(get_summary, _From, #state{events=Evts, links=Links}=State) ->
    {reply, generate_summary(Evts, Links), State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({link, ReqId, CallId}, #state{links=Links}=State) ->
    {noreply, State#state{links=[{ReqId, CallId} | Links]}};
handle_cast({start=Event, CallId}, #state{events=Evts}=State) ->
    {noreply, State#state{events=[{CallId, {Event, erlang:now()}} | Evts]}};
handle_cast({{resp_evt, "CHANNEL_HANGUP"}=Event, CallId}, #state{events=Evts}=State) ->
    {noreply, State#state{events=[{CallId, {Event, erlang:now()}} | Evts]}};
%%handle_cast({Event, ReqId}, #state{events=Evts}=State) ->
%%    {noreply, State};
%%{noreply, State#state{events=[{ReqId, {Event, erlang:now()}} | Evts]}};
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

generate_summary(Evts, Links) ->
    Converted = convert_reqids_to_callids(Evts, Links),

    CallIds = proplists:get_keys(Converted),
    lists:map(fun(CallId) ->
		      StartTime = get_start_time(CallId, Converted),
		      EndTime = get_end_time(CallId, Converted),
		      {CallId, timer:now_diff(EndTime, StartTime) div 1000}
	      end, CallIds).

get_start_time(CallId, Converted) ->
    Vals = proplists:get_all_values(CallId, Converted),
    case proplists:get_value(start, Vals) of
	undefined ->
	    io:format("Undefined start time for CID: ~p Vs: ~p~n", [CallId, Vals]),
	    erlang:now();
	 S -> S
    end.

get_end_time(CallId, Converted) ->
    Vals = proplists:get_all_values(CallId, Converted),
    proplists:get_value({resp_evt, "CHANNEL_HANGUP"}, Vals).

%% generate_report([{ReqId, {Evt, Timestamp}}]) -> [{CallId, Tdiff(milli), Evt}]
%% ReqId, for events, is the CallId.
generate_report(Evts, Links) ->
    Converted = convert_reqids_to_callids(Evts, Links),

    Res = lists:foldl(fun({CallId, {Evt, Tstamp}}, Res) ->
			      Start = get_start_time(CallId, Converted),
			      [{CallId, {timer:now_diff(Tstamp, Start) div 1000, Evt}} | Res]
		      end, [], lists:reverse(Converted)),
    lists:reverse(Res).

convert_reqids_to_callids(Evts, Links) ->
    lists:map(fun({ReqId, {start, _Tstamp}=Evt}) ->
		      {proplists:get_value(ReqId, Links), Evt};
		 ({ReqId, {req_callid, _Tstamp}=Evt}) ->
		      {proplists:get_value(ReqId, Links), Evt};
		 ({ReqId, {resp_callid, _Tstamp}=Evt}) ->
		      {proplists:get_value(ReqId, Links), Evt};
		 (Other) ->
		      Other
	      end, Evts).