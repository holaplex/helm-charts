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
local ngx         = ngx
local ngx_time    = ngx.time
local re_match    = ngx.re.match
local pairs       = pairs
local ipairs      = ipairs
local type        = type
local lrucache = core.lrucache.new({
    type = "plugin",
})
local _M = {}


-- build a table of Nginx variables with some generality
-- between http subsystem and stream subsystem
local function build_var(conf, ctx)
    return {
        server_addr = ctx.var.server_addr,
        server_port = ctx.var.server_port,
        remote_addr = ctx.var.remote_addr,
        remote_port = ctx.var.remote_port,
        timestamp   = ngx_time(),
    }
end

local function build_http_request(conf, ctx)
    local request = {
        scheme  = core.request.get_scheme(ctx),
        method  = core.request.get_method(),
        host    = core.request.get_host(ctx),
        port    = core.request.get_port(ctx),
        path    = ctx.var.uri,
        headers = core.request.headers(ctx),
        query   = core.request.get_uri_args(ctx),
    }

    if conf.with_body then
        request.body = core.request.get_body()
    end
    return request
end


local function build_http_route(conf, ctx, remove_upstream)
    local route = core.table.clone(ctx.matched_route).value

    if remove_upstream and route and route.upstream then
        route.upstream = nil
    end

    return route
end


local function build_http_service(conf, ctx)
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


local function build_http_consumer(conf, ctx)
    -- possible that there is no consumer bound to the route
    if ctx.consumer then
        return core.table.clone(ctx.consumer)
    end

    return nil
end

local function check_set_inputs(inputs)
    for field, value in pairs(inputs) do
        if type(field) ~= 'string' then
            return false, 'invalid type as input field'
        end

        if type(value) ~= 'string' and type(value) ~= 'number' then
            return false, 'invalid type as input value'
        end

        if #field == 0 then
            return false, 'invalid field length in input'
        end
    end

    return true
end

local function is_new_inputs_conf(inputs)
    return
        (inputs.add and type(inputs.add) == "table") or
        (inputs.set and type(inputs.set) == "table") or
        (inputs.remove and type(inputs.remove) == "table")
end

local function build_extra_inputs(inputs)
    local set = {}
    local add = {}
    if is_new_inputs_conf(inputs) then
        if inputs.add then
            for _, value in ipairs(inputs.add) do
                local m, err = re_match(value, [[^([^:\s]+)\s*:\s*([^:]+)$]], "jo")
                if not m then
                    return nil, err
                end
                core.table.insert_tail(add, m[1], m[2])
            end
        end

        if inputs.set then
            for field, value in pairs(inputs.set) do
                --reform header from object into array, so can avoid use pairs, which is NYI
                core.table.insert_tail(set, field, value)
            end
        end

    else
        for field, value in pairs(inputs) do
            core.table.insert_tail(set, field, value)
        end
    end

    return {
        add = add,
        set = set,
        remove = inputs.remove or {},
    }
end

function _M.build_opa_input(conf, ctx, subsystem)
    local data = {
        type    = subsystem,
        request = build_http_request(conf, ctx),
        var     = build_var(conf, ctx),
        extra   =  {}
    }

    if conf.with_route then
        data.route = build_http_route(conf, ctx, true)
    end
    
    if conf.with_consumer then
        data.consumer = build_http_consumer(conf, ctx)
    end

    if conf.with_service then
        data.service = build_http_service(conf, ctx)
    end
    
    if conf.extra_inputs then
      if conf.inputs then
          if not is_new_inputs_conf(conf.inputs) then
              local ok, err = check_set_inputs(conf.inputs)
              if not ok then
                  return false
              end
          end
      end
    local input_op, err = core.lrucache.plugin_ctx(lrucache, ctx, nil, build_extra_inputs, conf.inputs)
      if not input_op then
          core.log.error("failed to create inputs: ", err)
          return 503, "failed to create inputs"
      end 
    local field_cnt = #input_op.set
    for i = 1, field_cnt, 2 do
        -- { ['uid'] = 'xxx'}
        local val = core.utils.resolve_var(input_op.set[i+1], ctx.var)
        data.extra[input_op.set[i]] = val
    end

    end

    return {
        input = data,
    }
end


return _M
