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
    zero(wm,104);zero(cm,96);p(game+0x276c9f0,wm);p(game+0x276c390,cm)
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
assert(s.fire.mode==1 and s.fire.node==15 and s.fire.trigger and s.fire.pause==12 and s.fire.resume==4)
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
