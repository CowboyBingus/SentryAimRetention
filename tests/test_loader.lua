local source=assert(arg[1])
local function test(kind,loader,rejected)
    local env=setmetatable({print=function()end,os={getenv=function()end}},{__index=_G});env._G=env
    if loader==nil then loader={api=1,version=kind=='old_loader' and 6 or 7} end
    env.CowboyBingusModLoader=loader
    local calls,restores=0,0
    env.update=function(...)
        if kind=='update_error' then error('original update error') end
        return 1,nil,3
    end
    env.shutdown=function(...)return 4,nil,6 end
    local original=env.update
    local api={module=function(n)return n and 1 or 2 end,module_hash=function(n)return n==1 and 'game' or 'exe' end}
    local patch={apply=function(a,g,e,state)
        assert(a==api and g==1 and e==2);calls=calls+1;state.pending={}
        if kind=='patch_error' then error('patch error') end
        if kind=='patch_failure' then return false,'failed',false end
        if kind=='initializing' and calls<=4 then state.pending=nil;return true,'waiting_for_mission_global_276c3d0',false end
        return true,'ready',true
    end,stop=function(a,g,e,state)restores=restores+1;return true end}
    local install=setfenv(assert(loadfile(source..'/archive_loader.lua')),env)()
    install(function()return api end,patch,{revision='test',game_sha256='game',exe_sha256='exe'})
    if kind=='old_loader' or rejected then
        assert(env.update==original and calls==0 and not env.SentryAimRetention.active)
        assert(env.SentryAimRetention.status:find('Bingus Shared Loader',1,true))
        return
    end
    local update=env.update
    install(function()error('duplicate load')end,patch,{})
    assert(env.update==update)
    if kind=='update_error' then assert(not pcall(env.update));assert(restores==1)
    else
        local a,b,c=env.update();assert(a==1 and b==nil and c==3)
        if kind=='normal' then assert(calls==2 and select('#',env.update())==3)
        elseif kind=='initializing' then
            assert(calls==2 and not env.SentryAimRetention.active)
            env.update();assert(calls==4 and not env.SentryAimRetention.active)
            env.update();assert(calls==6 and env.SentryAimRetention.active)
        else assert(calls==1 and restores==1);env.update();assert(calls==1) end
    end
    local a,b,c=env.shutdown();assert(a==4 and b==nil and c==6)
end
for _,kind in ipairs({'normal','initializing','old_loader','update_error','patch_error','patch_failure'}) do test(kind)end
for _,loader in ipairs({{api=1,version=7},{api=2,version=7},{api=2,version=7},{api=99,version=100}}) do
    test('normal',loader)
end
for _,loader in ipairs({false,{}, {api=0,version=6},{api=2,version=6},
    {api='1',version=6},{api=1,version='6'},{api=1}}) do
    test('normal',loader,true)
end
print('PASS: minimum/newer loader and API gates, duplicate loads, callback tuples, shutdown, update exceptions and failure isolation')

-- Routine gameplay must not write diagnostics unless explicitly enabled.
for _,diagnostics in ipairs({false,true})do
    local now,opens,profiles=0,0,0
    local e=setmetatable({print=function()end},{__index=_G});e._G=e
    e.CowboyBingusDiagnostics=diagnostics
    e.CowboyBingusModLoader={api=1,version=99,open_log=function()
        opens=opens+1;return {write=function()end,close=function()end}
    end}
    e.update=function()return 1,nil,3 end;e.shutdown=function()return 4,nil,6 end
    local api={time=function()return now end,module=function(n)return n or 'exe'end,
        module_hash=function()return 'hash'end,bind=function()return {}end,read=function()return ''end}
    local patch={interval=1/30,apply=function()return true,'waiting_for_mission',false end,
        profiler={new=function()profiles=profiles+1;return {}end},stop=function()return true end,cleanup=function()return true end}
    setfenv(assert(loadfile(source..'/archive_loader.lua')),e)()(function()return api end,patch,
        {revision='fixture',game_sha256='hash',exe_sha256='hash'})
    local startup=opens
    for i=1,600 do now=i/60;local a,b,c=e.update(1/60);assert(a==1 and b==nil and c==3)end
    assert(diagnostics and opens>startup or not diagnostics and opens==startup,'routine log writes require opt-in')

    e.shutdown();assert(opens>startup,'shutdown report remains available')
end
print('PASS: silent default, opt-in diagnostics, shutdown report and callback returns')
