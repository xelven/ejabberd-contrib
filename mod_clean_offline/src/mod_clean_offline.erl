%%%----------------------------------------------------------------------
%%% File    : mod_clean_offline.erl
%%% Author  : Allen Chan <xelven@gmail.com>
%%% Created : 10 May 2015 by Allen Chan <xelven@gmail.com>
%%%----------------------------------------------------------------------

-module(mod_clean_offline).

-behaviour(gen_server).
-behaviour(gen_mod).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("ejabberd_commands.hrl").

%
%% Copied from mod_offline.erl
-record(offline_msg, {us, timestamp, expire, from, to, packet}).

-export([start/2, stop/1]).
-export([remove_old_messages/1]).

-export([clean_by_day/1]).


-define(SUPERVISOR,ejabberd_sup).

-define(AC_PATH,"/var/lib/ejabberd/clean").


%% ====================================================================
%% API functions
%% ====================================================================

remove_old_messages(Days) ->
?INFO_MSG("Run remove by days = ~p",[Days]),
    {MegaSecs, Secs, _MicroSecs} = now(),
    S = MegaSecs * 1000000 + Secs - 60 * 60 * 24 * Days,
    MegaSecs1 = S div 1000000,
    Secs1 = S rem 1000000,
    TimeStamp = {MegaSecs1, Secs1, 0},
    {{Y,M,D},{H,Mi,A}} = calendar:local_time(),
    FC = lists:flatten(io_lib:format("~p~p~p", [Y,M,D])),
    File = string:join([?AC_PATH,FC,".log"],""),
    F = fun() ->
                mnesia:write_lock_table(offline_msg),
                mnesia:foldl(
                  fun(#offline_msg{timestamp = TS,packet=Pac} = Rec, _Acc)
                     when TS < TimeStamp ->
			  file:write_file(File,io_lib:fwrite("~p:~s.\n",[TS,xml:element_to_string(Pac)]),[append]),
                          mnesia:delete_object(Rec);
                     (_Rec, _Acc) -> ok
                  end, ok, offline_msg)
        end,
    mnesia:transaction(F).

clean_by_day(D) ->
remove_old_messages(D),
ok.


common() ->
[
#ejabberd_commands{name = clean_by_day, tags = [server],
                   desc = "Run...",
                   module = ?MODULE, function = clean_by_day,
                   args = [{base, integer}],
		   result = {res, rescode}}
].


%-spec start(host(), opts()) -> ok.
start(Host, Opts) ->
    ?INFO_MSG("starting mod_clean_offline", []),
	ejabberd_commands:register_commands(common()),
	ok.

%-spec stop(host()) -> ok.
stop(Host) ->
    ?INFO_MSG("stopping mod_clean_offline", []),
    ejabberd_commands:unregister_commands(common()),
	ok.

