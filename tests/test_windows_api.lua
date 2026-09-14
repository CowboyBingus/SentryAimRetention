local source=assert(arg[1])
local ffi=require('ffi')
local create=assert(loadfile(source..'/windows_api.lua'))()
local api=create()
-- Repeated initialization shares declarations in the loader's Lua VM.
local again=create()
ffi.cdef [[
    void *VirtualAlloc(void *address, size_t size, uint32_t allocation, uint32_t protection);
    int VirtualFree(void *address, size_t size, uint32_t operation);
    int VirtualProtect(void *address, size_t size, uint32_t protection, uint32_t *previous);
]]
local kernel=ffi.load('kernel32')
local allocation=kernel.VirtualAlloc(nil,8192,0x3000,4)
assert(allocation~=nil)
local data=ffi.cast('uint8_t *',allocation)
for _,a in ipairs({api,again}) do
    assert(a.writable_data(data,8192))
    assert(a.write(data+4095,'\x12\x34'))
    assert(a.read(data+4095,2)=='\x12\x34')
    assert(not a.write(a.module(nil),'\0'))
end
local previous=ffi.new('uint32_t[1]')
for _,protection in ipairs({2,0x20,0x40}) do
    assert(kernel.VirtualProtect(data+4096,4096,protection,previous)~=0)
    for _,a in ipairs({api,again}) do
        assert(not a.writable_data(data,8192))
        assert(not a.write(data+4095,'\x56\x78'))
        assert(a.read(data+4095,2)=='\x12\x34')
    end
end
assert(kernel.VirtualFree(data,0,0x8000)~=0)
assert(not api.writable_data(data,1) and not api.write(data,'\0'))
print('PASS: Windows adapter repeated initialization, writable data and guarded memory rejection')

-- Exercise the engine-layout reader against synthetic data. No game code is
-- invoked: pose resolution uses only guarded reads through the adapter.
do
    local actual_read=api.read;local memory={};local unit=0x400001
    local function scalar(kind,v)return ffi.string(ffi.new(kind..'[1]',v),ffi.sizeof(kind))end
    local function ptr(address,v)memory[address]=scalar('uint64_t',v)end
    local function uint(address,v)memory[address]=scalar('uint32_t',v)end
    ptr(0x200000+0x1a140f0,0x300000);uint(0x300098,2)
    ptr(0x3000a0,0x400000);memory[0x400001]='\1'
    ptr(0x300088,0x500000);ptr(0x500008,0x600000)
    uint(0x600008,unit);uint(0x600070,2);ptr(0x600000,0x700000)
    ptr(0x7000e8,0x800000);memory[0x800000]='\x48\x8d\x41\x60\xc3'
    ptr(0x600088,0x900000);memory[0x900040]=string.rep('m',64)
    api.read=function(address,size)
        local b=memory[tonumber(ffi.cast('uintptr_t',address))]
        if b and #b==size then return b end
    end
    local binding=api.bind(ffi.cast('uint8_t *',0x100000),ffi.cast('uint8_t *',0x200000))
    assert(binding.pose(unit,1)==memory[0x900040])
    assert(not pcall(binding.pose,unit,2))
    memory[0x400001]='\2';assert(not pcall(binding.pose,unit,1));memory[0x400001]='\1'
    uint(0x600008,unit+1);assert(not pcall(binding.pose,unit,1));uint(0x600008,unit)
    memory[0x800000]='wrong';assert(not pcall(binding.pose,unit,1))
    api.read=actual_read
    print('PASS: muzzle pose unit generations, identity, bone bounds and native layout guards')
end
