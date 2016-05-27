%%--------------------------------------------------------------------
%% Copyright (c) 2016 Feng Lee <feng@emqtt.io>.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqttd_plugin_mysql_app).

-behaviour(application).

%% Application callbacks
-export([start/2, prep_stop/1, stop/1]).

-define(APP, emqttd_plugin_mysql).

%%--------------------------------------------------------------------
%% Application callbacks
%%--------------------------------------------------------------------

start(_StartType, _StartArgs) ->
    {ok, Sup} = emqttd_plugin_mysql_sup:start_link(),
    SuperQuery = application:get_env(?MODULE, superquery, undefined),
    ok = register_auth_mod(SuperQuery), ok = register_acl_mod(SuperQuery),
    {ok, Sup}.

register_auth_mod(SuperQuery) ->
    {ok, AuthQuery} = application:get_env(?MODULE, authquery),
    {ok, HashType}  = application:get_env(?MODULE, password_hash),
    AuthEnv = {SuperQuery, AuthQuery, HashType},
    emqttd_access_control:register_mod(auth, emqttd_auth_mysql, AuthEnv).

register_acl_mod(SuperQuery) ->
    with_acl_enabled(fun(AclQuery) ->
        SuperQuery       = application:get_env(?MODULE, superquery, undefined),
        {ok, AclNomatch} = application:get_env(?MODULE, acl_nomatch),
        emqttd_access_control:register_mod(acl, emqttd_acl_mysql, {SuperQuery, AclQuery, AclNomatch})
    end).

prep_stop(State) ->
    emqttd_access_control:unregister_mod(auth, emqttd_auth_mysql),
    with_acl_enabled(fun(_AclQuery) ->
        emqttd_access_control:unregister_mod(acl, emqttd_acl_mysql)
    end),
    State.

stop(_State) ->
    ok.

with_acl_enabled(Fun) ->
    case application:get_env(?MODULE, aclquery) of
        {ok, AclQuery} -> Fun(AclQuery);
        undefined      -> ok
    end.

