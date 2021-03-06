%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is VMware, Inc.
%% Copyright (c) 2007-2011 VMware, Inc.  All rights reserved.
%%

-module(rabbit_msg_store_index).

-export([behaviour_info/1]).

behaviour_info(callbacks) ->
    [{new,            1},
     {recover,        1},
     {lookup,         2},
     {insert,         2},
     {update,         2},
     {update_fields,  3},
     {delete,         2},
     {delete_by_file, 2},
     {terminate,      1}];
behaviour_info(_Other) ->
    undefined.
