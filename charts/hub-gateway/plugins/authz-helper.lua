-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

local core        = require("apisix.core")
local get_service = require("apisix.http.service").get
local json        = require("apisix.core.json")
local ngx         = ngx
local ngx_time    = ngx.time
local _M = {}


-- build a table of Nginx variables with some generality
-- between http subsystem and stream subsystem
local function build_var(ctx)
    return {
        server_addr = ctx.var.server_addr,
        server_port = ctx.var.server_port,
        remote_addr = ctx.var.remote_addr,
        remote_port = ctx.var.remote_port,
        timestamp   = ngx_time(),
    }
end

local function build_http_request(ctx)
    return {
        scheme  = core.request.get_scheme(ctx),
        method  = core.request.get_method(),
        host    = core.request.get_host(ctx),
        port    = core.request.get_port(ctx),
        path    = ctx.var.uri,
        headers = core.request.headers(ctx),
        query   = core.request.get_uri_args(ctx),
    }
end


local function build_http_route(ctx, remove_upstream)
    local route = core.table.clone(ctx.matched_route).value

    if remove_upstream and route and route.upstream then
        route.upstream = nil
    end

    return route
end


local function build_http_service(ctx)
    local service_id = ctx.service_id

    -- possible that there is no service bound to the route
    if service_id then
        local service = core.table.clone(get_service(service_id)).value

        if service then
            if service.upstream then
                service.upstream = nil
            end
            return service
        else
        core.log.error("failed to get service")
        end
    end

    return nil
end

local function build_graphql_data(ctx)
    local input = json.decode(core.request.get_body())
    return {
        query = input['query'],
        variables = input['variables'] or {},
        operation = ctx.var.graphql_operation,

    }
end

local function build_http_consumer(ctx)
    -- possible that there is no consumer bound to the route
    if ctx.consumer then
        return core.table.clone(ctx.consumer)
    end

    return nil
end

function _M.build_opa_input(conf, ctx, subsystem)
    local data = {
        type    = subsystem,
        request = build_http_request(ctx),
        var     = build_var(ctx),
        graphql = build_graphql_data(ctx),
        keto_endpoint = conf.keto_endpoint
    }

    if conf.with_route then
        data.route = build_http_route(ctx, true)
    end

    if conf.with_consumer then
        data.consumer = build_http_consumer(ctx)
    end

    if conf.with_service then
        data.service = build_http_service(ctx)
    end

    return {
        input = data,
    }
end

return _M
