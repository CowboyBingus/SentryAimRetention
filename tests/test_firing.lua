local src=assert(arg[1]);local ffi=require('ffi')
local M=assert(loadfile(src..'/aim_data.lua'))()
local function pack(kind,values)return ffi.string(ffi.new(kind..'['..#values..']',values),ffi.sizeof(kind)*#values)end
local function word(n)return pack('uint32_t',{n})end
local function fixture(pause,resume)
    local modes,writes={[100]=word(1)},{}
    local api={read=function(a,n)if a==10 then return 'identity' end;return modes[a]end,
        writable_data=function(a,n)return a==100 and n==4 end}
    local native={fire_mode=function(manager,id,mode)modes[100]=word(mode);writes[#writes+1]=mode end}
    local s={id=1,key='sentry',profile='Gatling',guards={{address=10,bytes='identity'}},
        enabled=true,has=true,target=1,runtime_target=1,source_flags=3,
        fire={manager=20,mode_address=100,mode=1,unit=1,node=1,guards={},trigger=true,pause=pause or 16,resume=resume or 4}}
    local function aim(degrees,bearing)
        local d=math.rad(degrees+(bearing or 0));local b=math.rad(bearing or 0)
        s.computed=pack('float',{math.sin(d)*20,math.cos(d)*20,0})
        s.fire.pose=pack('float',{1,0,0,0,math.sin(b),math.cos(b),0,0,0,0,1,0,0,0,0,1})
    end
    local state={native=native}
    local function step(t,degrees,bearing)
        s.fire.mode=tonumber(ffi.cast('const uint32_t *',modes[100])[0]);aim(degrees,bearing)
        return M.fire_step(api,native,{s},state,t)
    end
    return s,state,step,writes,api,native,modes
end
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS: '..name)end
test('production profiles and immediate angular limits match the tuned allowances',function()
    for _,profile in pairs(M.profiles)do
        if profile.fire_gate then
            local gate=profile.fire_gate
            assert(gate.pause==(profile.name=='Gatling' and 16 or 14))
            local s,state,step,writes=fixture(gate.pause,gate.resume)
            step(0,1);step(.08,1);step(.1,gate.pause-.01);assert(#writes==0)
            step(.12,gate.pause+.01);assert(writes[1]==0)
        end
    end
end)
test('Gatling keeps firing through a nearby target change; machine gun has a narrower allowance',function()
    for _,policy in ipairs({{16,4,13.95},{14,3,13.57}})do
        local s,state,step,writes=fixture(unpack(policy))
        assert(step(0,1));assert(step(.08,1));s.target=2;s.runtime_target=2
        assert(step(.10,policy[3],1));assert(step(.14,2,4));assert(step(.21,1,5))
        assert(#writes==0 and state.fire_paused==0)
    end
end)
test('target-loss pauses reopen immediately for a close replacement with a fresh clear path',function()
    for _,policy in ipairs({{16,4,13.95},{14,3,13.57}})do
        local s,state,step,writes=fixture(unpack(policy))
        s.fire.terrain_blocked=false;step(0,1);step(.08,1)
        s.target=0;s.has=false;step(.1,1)
        assert(#writes==1 and writes[1]==0)
        step(.8,1);assert(#writes==1) -- no rounds during the observed long target gap
        s.target=2;s.runtime_target=2;s.has=true
        step(.81,policy[3]);assert(#writes==2 and writes[2]==1)
        step(.84,2,4);step(.91,1,5);assert(#writes==2)
    end
end)
test('handoff requires synchronized aim and a fresh clearance result',function()
    local s,state,step,writes=fixture();s.fire.terrain_blocked=false
    step(0,1);step(.08,1);s.target=0;s.has=false;step(.1,1)
    s.target=2;s.has=true;s.fire.terrain_blocked=nil
    step(.8,10);assert(#writes==1) -- runtime target still old
    s.runtime_target=2;step(.82,10);assert(#writes==1) -- no completed query
    s.fire.terrain_blocked=false;step(.84,10);assert(#writes==2)
end)
test('stale retained aim cannot keep firing at a different selected target',function()
    local s,state,step,writes=fixture();s.fire.terrain_blocked=false
    step(0,1);step(.08,1)
    s.target=2 -- runtime target and computed aim still belong to target 1
    step(.1,1);assert(#writes==1 and writes[1]==0)
    for i=1,100 do step(.1+i*.1,1)end
    assert(#writes==1 and state.fire_records[1].reason=='aim_pending')
    s.runtime_target=2;step(10.2,8);assert(#writes==2 and writes[2]==1)
end)
test('a wide reacquisition or intervening obstruction cancels the handoff shortcut',function()
    for _,cause in ipairs({'turn','terrain'})do
        local s,state,step,writes=fixture();s.fire.terrain_blocked=false
        step(0,1);step(.08,1);s.target=0;s.has=false;step(.1,1)
        s.target=2;s.runtime_target=2;s.has=true
        s.fire.terrain_blocked=cause=='terrain';step(.8,cause=='turn' and 90 or 10)
        s.fire.terrain_blocked=false;step(.9,10);assert(#writes==1)
        step(.94,2);step(.98,2);assert(#writes==1)
        step(1.01,2);assert(#writes==2)
    end
end)
test('a partial close turn before loss does not count paused time against the next handoff',function()
    local s,state,step,writes=fixture();s.fire.terrain_blocked=false
    step(0,1);step(.08,1);step(.1,8,2)
    s.target=0;s.has=false;step(.12,8,2);step(.9,8,2)
    s.target=2;s.runtime_target=2;s.has=true;step(.92,10,2)
    assert(#writes==2 and writes[2]==1)
end)
test('target loss cannot turn an existing broad-sweep pause into an immediate handoff',function()
    local s,state,step,writes=fixture();s.fire.terrain_blocked=false
    step(0,90);s.target=0;s.has=false;step(.1,0)
    s.target=2;s.runtime_target=2;s.has=true;step(.5,10);assert(#writes==1)
    step(.6,2);step(.67,2);assert(#writes==2)
end)
test('84 and 180 degree sweeps pause; hysteresis prevents early reopening',function()
    for _,turn in ipairs({84,180})do
        local s,state,step,writes=fixture();assert(step(0,1));s.target=2;s.runtime_target=2
        assert(step(.10,turn));assert(state.fire_paused==1 and writes[1]==0)
        assert(step(.16,10));assert(step(.20,5));assert(#writes==1)
        assert(step(.25,3));assert(step(.28,3));assert(#writes==1)
        assert(step(.32,2));assert(writes[2]==1 and state.fire_paused==0)
        assert(s.fire.trigger) -- shot permission never releases the AI trigger
    end
end)
test('long unsettled adjustments and chained small turns cannot extend the firing sweep indefinitely',function()
    local s,state,step,writes=fixture();step(0,1);step(.08,1)
    step(.10,7,1);step(.21,7,2);step(.31,7,3)
    assert(writes[1]==0 and state.fire_paused==1)
    s,state,step,writes=fixture();step(0,1);step(.08,1)
    step(.10,6,6);step(.14,6,12);step(.18,6,18)
    assert(writes[1]==0)
end)
test('moving-target tracking keeps firing; target loss stops a stationary residual burst',function()
    local s,state,step,writes=fixture()
    for i=0,50 do assert(step(i*.02,1,i)) end
    s.target=0;s.has=false
    assert(#writes==0)
    assert(step(1.1,80,50));assert(step(1.5,80,50));assert(#writes==1 and writes[1]==0)
    s.flags=2;s.horizontal=word(0);s.vertical=word(0)
    assert(step(1.6,0,50));assert(step(1.8,0,50));assert(#writes==1)
    s.target=2;s.runtime_target=2;s.has=true
    assert(step(1.9,0,50));assert(step(1.98,0,50));assert(writes[2]==1)
end)
test('terrain blocks an aligned downward aim until a crawler or tentacle is exposed',function()
    for _,policy in ipairs({{16,4},{14,3}})do
        local s,state,step,writes=fixture(unpack(policy))
        s.fire.terrain_blocked=false;step(0,0);step(.08,0);assert(#writes==0)
        s.fire.terrain_blocked=true;step(.10,0)
        assert(writes[1]==0 and state.fire_records[1].reason=='terrain_blocked')
        for i=1,100 do step(.10+i*.02,0) end
        assert(#writes==1) -- settled aim below terrain cannot reopen fire
        s.fire.terrain_blocked=nil;step(2.2,0);assert(#writes==1) -- pending native workers
        s.fire.terrain_blocked=false;step(2.3,0);step(2.34,0);assert(#writes==1)
        step(2.38,0);assert(writes[2]==1 and s.fire.trigger)
    end
end)
test('blocked target state does not leak into a replacement target or override external fire mode',function()
    local s,state,step,writes,api,native,modes=fixture()
    s.fire.terrain_blocked=true;step(0,0)
    s.target=2;s.runtime_target=2;s.fire.terrain_blocked=false
    step(.1,0);step(.18,0);assert(writes[2]==1)
    s.fire.terrain_blocked=true;step(.2,0);modes[100]=word(3)
    assert(M.stop(api,nil,nil,state));assert(modes[100]==word(3))
end)
test('loss and terrain pauses release for scanning after the trigger is released',function()
    local s,state,step,writes=fixture();s.fire.terrain_blocked=true;step(0,0)
    s.target=0;s.has=false;s.fire.trigger=false;step(.1,0)
    assert(writes[2]==1 and state.fire_paused==0)
end)
test('paused target loss waits for native trigger release; no permanent firing lock',function()
    local s,state,step,writes=fixture();step(0,84);s.target=0;s.has=false
    step(.1,1);assert(#writes==1)
    s.fire.trigger=false;step(.2,1);assert(writes[2]==1)
    s.target=2;s.runtime_target=2;s.has=true;s.fire.trigger=true;step(.3,1);assert(#writes==2)
end)
test('pre-existing no-fire mode, external changes, failed calls and shutdown preserve ownership',function()
    local s,state,step,writes,api,native,modes=fixture();modes[100]=word(0);step(0,90)
    assert(#writes==0);assert(M.stop(api,nil,nil,state));assert(modes[100]==word(0))
    s,state,step,writes,api,native,modes=fixture();step(0,90);modes[100]=word(3)
    assert(M.stop(api,nil,nil,state));assert(modes[100]==word(3))
    s,state,step,writes,api,native,modes=fixture()
    native.fire_mode=function(_,_,mode)modes[100]=word(mode);if mode==0 then error('after mutation')end end
    assert(not pcall(step,0,90));assert(M.stop(api,nil,nil,state));assert(modes[100]==word(1))
end)
test('fresh identity guards restore relocated leases and reject stale entities',function()
    local s,state,step,writes,api,native,modes=fixture();step(0,90)
    s.fire.mode_address=200;modes[200]=word(0)
    api.writable_data=function(a,n)return a==200 and n==4 end
    native.fire_mode=function(_,_,mode)modes[200]=word(mode)end
    s.fire.mode=0;M.fire_step(api,native,{s},state,.1)
    assert(M.stop(api,nil,nil,state));assert(modes[200]==word(1))
    s,state,step,writes,api,native,modes=fixture();step(0,90)
    api.read=function(a)if a==10 then return 'recycled' end;return modes[a]end
    assert(M.stop(api,nil,nil,state));assert(modes[100]==word(0))
end)
test('invalid muzzle data fails before a fire-mode write',function()
    local s,state,step,writes,api,native=fixture();step(0,1)
    s.fire.pose=string.rep('\0',64)
    assert(not pcall(M.fire_step,api,native,{s},state,.1));assert(#writes==0)
end)
local function selection_fixture()
    local s,state,fire,writes,api,native,mem=fixture()
    local function tickword(n)return pack('uint64_t',{n})end
    mem[200]=tickword(1800000);mem[308]=word(12);mem[30]='clockptr'
    s.node=12;s.behavior_address=300
    s.selection={address=200,now=1000000,deadline=mem[200],guards={{address=30,bytes='clockptr'}}}
    local edits={}
    api.write=function(a,b)mem[a]=b;edits[#edits+1]={a,b};return true end
    api.writable_data=function(a,n)return (a==100 and n==4) or (a==s.selection.address and n==8)end
    local function step(t)
        mem[308]=word(s.node);s.selection.now=math.floor(t*1000000)
        s.selection.deadline=mem[s.selection.address]
        assert(fire(t,1));return M.selection_step(api,{s},state)
    end
    return s,state,step,edits,api,native,mem,tickword
end

test('target loss expires a pending native search once without reopening residual fire',function()
    local s,state,step,edits,api,native,mem,tickword=selection_fixture()
    s.fire.terrain_blocked=false;assert(step(1));assert(#edits==0)
    s.target=0;s.has=true;s.source_flags=32;assert(step(1.1))
    assert(mem[200]==tickword(1100000) and state.reselections==1 and mem[100]==word(0))
    assert(step(1.11));assert(#edits==1)
    -- Model the decoded handler's deadline branch: native query now runs at
    -- 1.12s instead of waiting until 1.80s, and selects the adjacent candidate.
    local due=tonumber(ffi.cast('const uint64_t *',mem[200])[0])<=1120000
    assert(due);mem[200]=tickword(2120000)
    s.target=2;s.runtime_target=2;s.has=true;s.source_flags=3;assert(step(1.12))
    assert(mem[100]==word(1) and #edits==1 and not state.fire_records[1].selection)
    s.target=0;s.has=false;assert(step(1.2));assert(state.reselections==2)
    mem[200]=tickword(1450000) -- native search found no eligible replacement
    assert(step(1.22));assert(step(1.5));assert(step(2))
    assert(#edits==2 and mem[100]==word(0)) -- do not force repeated idle searches
end)

test('repeated invalid targets cannot force native searches every frame',function()
    local s,state,step,edits,api,native,mem,tickword=selection_fixture()
    step(1);s.target=0;s.has=false;step(1.1)
    mem[200]=tickword(2110000);s.target=1;s.runtime_target=1;s.has=true;step(1.11)
    s.target=0;s.has=false;step(1.13)
    assert(mem[200]==tickword(1200000) and state.reselections==2)
    assert(step(1.14));assert(#edits==2)
end)

test('selection requests require an observed loss on the enabled firing node and a bounded future timer',function()
    for _,cause in ipairs({'first_sample','scanning','disabled','overdue','long_timer','invalid_clock','same_target'})do
        local s,state,step,edits,api,native,mem,tickword=selection_fixture()
        if cause~='first_sample' then assert(step(1))end
        if cause~='same_target' then s.target=0;s.has=false end
        if cause=='scanning' then s.node=2
        elseif cause=='disabled' then s.enabled=false
        elseif cause=='overdue' then mem[200]=tickword(1000000)
        elseif cause=='long_timer' then mem[200]=tickword(5000000)end
        assert(step(cause=='invalid_clock' and 0 or 1.1));assert(#edits==0,cause)
    end
end)

test('unconsumed selection requests restore on shutdown but preserve native deadline changes',function()
    for _,consumed in ipairs({false,true})do
        local s,state,step,edits,api,native,mem,tickword=selection_fixture()
        step(1);s.target=0;s.has=false;step(1.1)
        if consumed then mem[200]=tickword(2100000)end
        assert(M.stop(api,nil,nil,state))
        assert(mem[200]==tickword(consumed and 2100000 or 1800000) and mem[100]==word(1))
    end
end)

test('selection request failures retain rollback ownership including partial writes',function()
    for _,cut in ipairs({0,1,3,7,8})do
        local s,state,step,edits,api,native,mem,tickword=selection_fixture()
        step(1);s.target=0;s.has=false
        local write=api.write
        api.write=function(a,b)mem[a]=b:sub(1,cut)..mem[a]:sub(cut+1);error('partial timer write')end
        assert(not pcall(step,1.1));api.write=write
        assert(M.stop(api,nil,nil,state));assert(mem[200]==tickword(1800000))
        assert(mem[100]==word(1))
    end
end)

test('selection requests reject changed guards and non-writable runtime data before writing',function()
    for _,cause in ipairs({'entity','clock','transition','memory'})do
        local s,state,step,edits,api,native,mem=selection_fixture()
        step(1);s.target=0;s.has=false
        -- Do not request a fire-mode mutation in this test; isolate timer guards.
        mem[100]=word(0)
        if cause=='entity' then local read=api.read;api.read=function(a,n)if a==10 then return 'recycled' end;return read(a,n)end
        elseif cause=='clock' then mem[30]='newclock'
        elseif cause=='transition' then s.transition_guards={{address=400,bytes='oldstate'}};mem[400]='newstate'
        else api.writable_data=function()return false end end
        assert(not step(1.1));assert(#edits==0)
    end
end)

test('selection lease follows fresh maps and component relocation without restoring recycled state',function()
    local s,state,step,edits,api,native,mem,tickword=selection_fixture()
    step(1);s.target=0;s.has=false;step(1.1)
    mem[30]='newclock';s.selection.guards={{address=30,bytes='newclock'}}
    mem[500]=mem[200];s.selection.address=500
    assert(step(1.12));assert(M.stop(api,nil,nil,state))
    assert(mem[500]==tickword(1800000) and mem[200]==tickword(1100000))
    s,state,step,edits,api,native,mem,tickword=selection_fixture()
    step(1);s.target=0;s.has=false;step(1.1);mem[308]=word(2)
    assert(M.stop(api,nil,nil,state));assert(mem[200]==tickword(1100000))
end)
if arg[2] then
test('recorded broad Gatling sweep is suppressed while nearby changes keep firing',function()
    local replay=assert(loadfile(arg[2]))();local records={};local broad,blocked,mg_shots,mg_allowed=0,0,0,0
    local lost_shots,lost_blocked=0,0
    for _,row in ipairs(replay)do
        local id=row[2];local record=records[id]
        if not record then
            local p=row[3]=='Gatling' and {16,4} or {14,3}
            record={fixture(unpack(p))};records[id]=record
        end
        local s,state,_,writes,api,native,modes=unpack(record)
        s.target=row[4];s.runtime_target=row[5];s.fire.trigger=row[6]==1
        s.has=row[7]==1;s.source_flags=row[8];s.enabled=row[9]==1
        s.computed=pack('float',row[10]);s.fire.pose=pack('float',row[11])
        s.flags=row[13] and 2 or 0
        s.horizontal=row[13] and word(0) or pack('float',{80});s.vertical=s.horizontal
        s.fire.mode=tonumber(ffi.cast('const uint32_t *',modes[100])[0])
        assert(M.fire_step(api,native,{s},state,row[1]))
        local _,error_angle=M.fire_geometry(s)
        if row[12]>0 and s.target~=0 and error_angle>12 then
            broad=broad+row[12];if modes[100]==word(0) then blocked=blocked+row[12]end
        end
        if row[3]=='Machine gun' then
            mg_shots=mg_shots+row[12];if modes[100]~=word(0) then mg_allowed=mg_allowed+row[12]end
            if s.target==0 then
                lost_shots=lost_shots+row[12]
                if modes[100]==word(0) then lost_blocked=lost_blocked+row[12] end
            end
        end
    end
    assert(broad>=8 and blocked==broad,string.format('broad=%d blocked=%d',broad,blocked))
    assert(mg_shots>20 and mg_allowed>0 and lost_shots>20 and lost_blocked==lost_shots)
    print(string.format('Replay: %d broad-sweep rounds gated; %d MG target-loss rounds gated; %d MG rounds retained',blocked,lost_blocked,mg_allowed))
end)
end
print(string.format('%d firing policy tests passed',passed))
