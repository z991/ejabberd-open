-module(http_auth_uk).

-export([handle/1]).
-include("ejabberd.hrl").
-include("logger.hrl").

handle(Req) ->
    auth_uk(Req).

auth_uk(Req)->
    ParsedQs = cowboy_req:parse_qs(Req),
    User = proplists:get_value(<<"u">>, ParsedQs),
    Key = proplists:get_value(<<"k">>, ParsedQs),
    do_verify_user_key(User, Key, Req).

do_verify_user_key(undefined, _, Req) ->
    http_utils:cowboy_req_reply_json(http_utils:gen_fail_result(1, <<"auth fail">>), Req);
do_verify_user_key(_, undefined, Req) ->
    http_utils:cowboy_req_reply_json(http_utils:gen_fail_result(1, <<"auth fail">>), Req);
do_verify_user_key(User, Key, Req) when is_binary(User),is_binary(Key)->
    case catch redis_link:hash_get(2,binary_to_list(User),binary_to_list(Key)) of
        {ok,undefined} -> http_utils:cowboy_req_reply_json(http_utils:gen_fail_result(1, <<"auth fail">>), Req);
        {ok,_ } -> http_utils:cowboy_req_reply_json(http_utils:gen_success_result(), Req);
        _ -> http_utils:cowboy_req_reply_json(http_utils:gen_fail_result(1, <<"auth fail">>), Req)
    end;
do_verify_user_key(_, _, Req) ->
     http_utils:cowboy_req_reply_json(http_utils:gen_fail_result(1, <<"auth fail">>), Req).

