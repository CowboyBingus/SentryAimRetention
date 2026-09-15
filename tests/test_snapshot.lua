local M=assert(loadfile(assert(arg[1])..'/aim_data.lua'))()
local ffi=require('ffi')
local function bytes(kind,v)return ffi.string(ffi.new(kind..'[1]',v),ffi.sizeof(kind))end
local function fixture()
    local mem={};local game=0x100000;local tm,bm,rm=0x500000,0x600000,0x700000
    local wm,cm=0x900000,0x910000
    local entity,rt,nt,behavior,control=0x800000,0x801000,0x802000,0x803000,0x804000
    local function put(a,b)for i=1,#b do mem[a+i-1]=b:sub(i,i)end end
    local function w(a,n)put(a,bytes('uint32_t',n))end
    local function p(a,n)put(a,bytes('uint64_t',n))end
    local function zero(a,n)put(a,string.rep('\0',n))end
    local api={}
    function api.read(a,n)local t={};for i=0,n-1 do if not mem[a+i]then return nil end;t[#t+1]=mem[a+i]end;return table.concat(t)end
    function api.pointer(b)return b and tonumber(ffi.cast('const uint64_t *',b)[0])end
    function api.bind()error('Unvalidated native binding')end
    zero(tm,392);zero(bm,112);zero(rm,96);zero(entity,24);zero(rt,208);zero(nt,24);zero(behavior,496);zero(control,16)
    p(game+0x276ca40,tm);p(game+0x276c470,bm);p(game+0x276ca80,rm)
    p(game+0x276c068,0x990000);p(0x990018,1000000);p(behavior+152,1700000)
    zero(wm,104);zero(cm,96);p(game+0x276c9f0,wm);p(game+0x276c390,cm)
    local fm=0x950000;zero(fm+73808,32);p(game+0x276c9c8,fm)
    p(fm+73808,0x980000);w(fm+73816,8);w(fm+73820,0);w(fm+73824,2)
    zero(0x980000,64);w(0x980010,77);w(0x980014,0)
    p(fm+73832,0x970000);p(0x970000,0x971000);zero(0x971000,20)
    w(0x971008,77);w(0x97100c,222)
    w(tm+308,384);w(tm+320,1);w(tm+324,1)
    w(bm+32,1024);w(rm+8,64);w(rm+20,1);w(rm+24,1)
    for _,spec in ipairs({{tm,336,360,0x810000},{bm,64,88,0x820000},{rm,40,64,0x830000},
        {wm,48,72,0x920000},{cm,40,64,0x930000}})do
        local m,o,e,map=unpack(spec);p(m+o,map);w(m+o+8,8);w(m+o+12,0);w(m+o+16,2)
        zero(map,64);w(map+16,9);w(map+20,0);p(m+e,map+128);p(map+128,entity)
    end
    p(tm+376,rt);p(tm+384,nt);p(bm+96,behavior);p(rm+88,control)
    zero(0x940000,992);p(wm+88,0x940000);w(0x940000+200,1);w(0x940000+104,15)
    zero(0x941000,12);p(wm+96,0x941000);w(0x941000,1);p(cm+88,0x942000);put(0x942000,'\1')
    put(entity,('\x70\x1d\xe3\x58\xcf\xd6\x85\xef'));w(entity+8,9);w(entity+12,1);w(entity+16,12);put(entity+20,'\1')
    w(behavior,212);w(behavior+8,12);w(behavior+24,77);w(behavior+96,3);put(behavior+120,'\1')
    w(rt,77);put(control,'\1');put(control+8,bytes('float',80));put(control+12,bytes('float',50))
    return api,game,put,w,p,{tm=tm,bm=bm,rm=rm,entity=entity,rt=rt,nt=nt,behavior=behavior,control=control}
end
local api,g,put,w,p,a=fixture()
local rows=M.snapshot(api,g);assert(#rows==1)
local s=rows[1];assert(s.id==9 and s.profile=='Gatling' and s.node==12 and s.target==77)
assert(s.runtime_target==77 and s.flags==0 and s.enabled and s.has)
assert(s.raw_address==a.rt+8 and s.flags_address==a.nt+16 and s.control_address==a.control)
assert(s.fire.mode==1 and s.fire.node==15 and s.fire.trigger and s.fire.pause==16 and s.fire.resume==4)
assert(s.fire.target_unit==222 and #s.fire.target_guards>0)
assert(s.selection.address==a.behavior+152 and s.selection.now==1000000)
assert(s.selection.deadline==bytes('uint64_t',1700000) and #s.selection.guards==1)
do
    local queried=false
    local state={native={
        pose=function()
            return ffi.string(ffi.new('float[16]',{1,0,0,0,0,1,0,0,0,0,1,0,0,-20,0,1}),64)
        end,
        terrain_path=function(unit,origin,target,target_unit)
            queried=true;assert(unit==1 and target==s.raw and #origin==12 and target_unit==222);return false
        end,
    }}
    api.time=function()return 0 end
    assert(M.apply(api,g,nil,state));assert(queried)
end
-- Target removal cannot invalidate restoration of the sentry's fire mode.
do
    local restored=false;local current=bytes('uint32_t',0);local read=api.read
    w(0x971008,78)
    api.read=function(address,size)if address==s.fire.mode_address then return current end;return read(address,size)end
    api.writable_data=function()return true end
    assert(M.release_fire(api,{fire_mode=function(_,_,mode)restored=true;current=bytes('uint32_t',mode)end},
        {snapshot=s,mode=1}))
    assert(restored);api.read=read;w(0x971008,77)
end
local count=0;for _ in pairs(M.profiles)do count=count+1 end;assert(count==7)
put(a.entity+20,'\0');assert(#M.snapshot(api,g)==0)
put(a.entity+20,'\3');assert(#M.snapshot(api,g)==0)
put(a.entity+20,'\1');w(a.behavior,999);assert(not pcall(M.snapshot,api,g));w(a.behavior,212)
w(a.bm+72,7);assert(not pcall(M.snapshot,api,g));w(a.bm+72,8)
p(0x820080,a.entity+24);assert(not pcall(M.snapshot,api,g));p(0x820080,a.entity)
put(a.rt+8,bytes('uint32_t',0x7fc00000));assert(not pcall(M.snapshot,api,g));put(a.rt+8,bytes('float',0))
assert(not pcall(M.apply,api,g,nil,{})) -- no setter signatures, so no binding or mutation
p(g+0x276ca40,0);local ok,why=M.apply(api,g,nil,{})
assert(ok and why=='waiting_for_sentries')
print('PASS: native-layout fixture, offsets, authority/resource gates, malformed maps/vectors and no binding before validation')
