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
        fire={manager=20,mode_address=100,mode=1,unit=1,node=1,guards={},trigger=true,pause=pause or 12,resume=resume or 4}}
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
test('Gatling keeps firing through a nearby target change; machine gun has a narrower allowance',function()
    for _,policy in ipairs({{12,4,10},{8,3,6}})do
        local s,state,step,writes=fixture(unpack(policy))
        assert(step(0,1));assert(step(.08,1));s.target=2;s.runtime_target=2
        assert(step(.10,policy[3],1));assert(step(.14,2,4));assert(step(.21,1,5))
        assert(#writes==0 and state.fire_paused==0)
    end
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
    step(.10,6,6);step(.14,6,10);step(.18,6,14)
    assert(writes[1]==0)
end)
test('normal moving-target tracking and a stationary target-loss hold keep firing',function()
    local s,state,step,writes=fixture()
    for i=0,50 do assert(step(i*.02,1,i)) end
    s.target=0;s.has=false
    assert(step(1.1,80,50));assert(step(1.5,80,50));assert(#writes==0)
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
if arg[2] then
test('recorded broad Gatling sweep is suppressed while nearby changes keep firing',function()
    local replay=assert(loadfile(arg[2]))();local records={};local broad,blocked,mg_shots,mg_allowed=0,0,0,0
    for _,row in ipairs(replay)do
        local id=row[2];local record=records[id]
        if not record then
            local p=row[3]=='Gatling' and {12,4} or {8,3}
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
        end
    end
    assert(broad>=8 and blocked==broad,string.format('broad=%d blocked=%d',broad,blocked))
    assert(mg_shots>20 and mg_allowed==mg_shots,string.format('MG shots=%d allowed=%d',mg_shots,mg_allowed))
    print(string.format('Replay: %d broad-sweep rounds gated; %d machine-gun rounds retained',blocked,mg_allowed))
end)
end
print(string.format('%d firing policy tests passed',passed))
