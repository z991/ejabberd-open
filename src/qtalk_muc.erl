%%%%%%----------------------------------------------------------------------
%%%%%% File    : qtalk_muc.erl
%%%%%% Purpose : qtalk_muc_room
%%%%%%----------------------------------------------------------------------

-module(qtalk_muc).

-include("ejabberd.hrl").
-include("logger.hrl").

-include("jlib.hrl").

-include("mod_muc_room.hrl").

-export([init_ets_muc_users/3]).
-export([get_muc_registed_user_num/2,set_muc_room_users/5,del_muc_room_users/5]).
-export([del_ets_muc_room_users/2]).

%%%%%%%%%%%--------------------------------------------------------------------
%%%%%%%%%%% @date 2017-03-01
%%%%%%%%%%% 初始化ets表，muc_users
%%%%%%%%%%%--------------------------------------------------------------------

init_ets_muc_users(Server,Muc, Domain) ->
    case catch qtalk_sql:get_muc_users(Server,Muc, Domain) of
    {selected,_,Res} when is_list(Res) ->
        UL = lists:flatmap(fun([U,H]) ->
                case str:str(H,<<"conference">>) of
                0 ->
                    [{U,H}];
                _ ->
                    []
               end end,Res),
        case UL of
        [] ->
            ok;
        _ ->
            ets:insert(muc_users,{{Muc, Domain},UL})
        end;
    _ ->
        ok
    end.

%%%%%%%%%%%--------------------------------------------------------------------
%%%%%%%%%%% @date 2017-03-01
%%%%%%%%%%% 向ets表中添加群用户成员
%%%%%%%%%%%--------------------------------------------------------------------

set_muc_room_users(Server,User,Room,Domain,Host) ->
    case ets:lookup(muc_users,{Room,Domain}) of
    [] ->
        U1 = case catch qtalk_sql:get_muc_users(Server,Room, Domain) of
            {selected, _,SRes}    when is_list(SRes) ->
                lists:flatmap(fun([U,H]) ->
                        [{U,H}] end,SRes);
            _ ->
                []
            end,
        do_set_muc_room_users(Server,Room, Domain, User,Host,U1);
    [{_,UL}] when is_list(UL) ->
        do_set_muc_room_users(Server,Room, Domain, User,Host,UL)
    end.

do_set_muc_room_users(Server,Room, Domain, User, Host,UL) ->
    case lists:member({User, Host},UL) of
    true ->
        catch ets:insert(muc_users,{{Room,Domain}, UL}),
        false;
    false ->
        U2 = lists:append([[{User, Host}],UL]),
        catch ets:insert(muc_users,{{Room,Domain}, U2}),
        catch qtalk_sql:insert_muc_users_sub_push(Server,Room, Domain, User, Host),
        true
    end.

%%%%%%%%%%% @date 2017-03-01
%%%%%%%%%%% 获取群用户注册的数量
%%%%%%%%%%%--------------------------------------------------------------------
get_muc_registed_user_num(Room,Domain) ->
    case ets:lookup(muc_users,{Room,Domain}) of
    [] ->
        0;
    [{_,U}] when is_list(U) ->
        length(U);
    _ ->
        0
    end.


%%%%%%%%%%%--------------------------------------------------------------------
%%%%%%%%%%% @date 2017-03-01
%%%%%%%%%%% 删除ets表中muc_room_users数据
%%%%%%%%%%%--------------------------------------------------------------------
del_muc_room_users(Server,Room, Domain, User,Host) ->
    case ets:lookup(muc_users,{Room,Domain}) of
    [] ->
        ok;
    [{_,UL}] when UL /= [] ->
        case lists:delete({User,Host},UL) of
        UL ->
            ok;
        UDL when is_list(UDL) ->
            if UDL =:= [] ->
                ets:delete(muc_users,{Room,Domain});
            true ->
                ets:insert(muc_users,{{Room,Domain},UDL})
            end;
        _ ->
            ok
        end;
    _ ->
        ok
    end,
    catch qtalk_sql:del_muc_user(Server,Room, Domain, User).

del_ets_muc_room_users(_Server,Room) ->
	catch ets:delete(muc_room_users,Room).
