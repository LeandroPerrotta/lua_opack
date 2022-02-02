local utf8 = require 'utf8/init'
utf8.config = {
  debug = nil, --utf8:require("util").debug
}
utf8:init()

-- some helper functions

--[[
The UUID base code is based on https://gist.github.com/jrus/3197011
]]
local random = math.random
local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

--[[
bytes <-> number utils
Note: in Lua, bytes are a string, that is a table
]]
function bytes_to_int(str,endian,signed) -- use length of string to determine 8,16,32,64 bits
    local t={str:byte(1,-1)}
    if endian=="big" then --reverse bytes
        local tt={}
        for k=1,#t do
            tt[#t-k+1]=t[k]
        end
        t=tt
    end
    local n=0
    for k=1,#t do
        n=n+t[k]*2^((k-1)*8)
    end
    if signed then
        n = (n > 2^(#t*8-1) -1) and (n - 2^(#t*8)) or n -- if last bit set, negative.
    end
    return n
end

function int_to_bytes(num,endian,signed)
    if num<0 and not signed then num=-num print"[int_to_bytes] Warning, dropping sign from number converting to unsigned" end
    local res={}
    local n = math.ceil(select(2,math.frexp(num))/8) -- number of bytes to be used.
    if signed and num < 0 then
        num = num + 2^n
    end
    for k=n,1,-1 do -- 256 = 2^8 bits per char.
        local mul=2^(8*(k-1))
        res[k]=math.floor(num/mul)
        num=num-res[k]*mul
    end
    assert(num==0)
    if endian == "big" then
        local t={}
        for k=1,n do
            t[k]=res[n-k+1]
        end
        res=t
    end

    return string.char(unpack(res))
end

function table.merge(origin, _table, bytes)

	bytes = bytes or 1

	local _b = 0

	if(type(_table) == 'string') then
		local t = {}
		_table:gsub(".", function(c) table.insert(t,c) end)

		_table = t
	elseif(_table == nil) then
		error('Trying to merge a nil value')
		return
	end

	for k, v in pairs(_table) do
		table.insert(origin, v)
		_b = _b + 1
	end

	-- we need fill up bytes, not sure if it will work, need test
	if(_b < bytes) then
		for i=b,bytes,1 do 
			table.insert(origin, int_to_bytes(0, "little"))
		end
	end
end

-- in Lua 5.3 we should use string.pack
-- but in older Lua, and without C, we have no choice than this workaround
function float_to_byte(x)
	local sign = 1
	local mantissa = string.byte(x, 3) % 128

	for i = 2, 1, -1 do mantissa = mantissa * 256 + string.byte(x, i) end

	if string.byte(x, 4) > 127 then sign = -1 end

	local exponent = (string.byte(x, 4) % 128) * 2 +
	               math.floor(string.byte(x, 3) / 128)

	if exponent == 0 then return 0 end

	mantissa = (math.ldexp(mantissa, -23) + 1) * sign

	return math.ldexp(mantissa, exponent - 127)
end


OPACK = {


}

function OPACK.pack(data, object_list)

	object_list = object_list or nil

	
	local message = {}

	local typeConvertCallbacks = {

		{ 
			condition = function(data) return data == nil end
			, callback = function(data)  
				table.insert(message, 0x04)
			end 
		}

		,{ 
			condition = function(data) return type(data) == "boolean" end
			, callback = function(data)  
				table.insert(message, data and 1 or 2)
			end 
		}

		,{ 
			condition = function(data) return type(data) == "table" end
			, callback = function(data)  

				-- lua doesnt has objects so we will need use a table. its the simplest way to achieve this in Lua
				if(data.type == "UUID") then
					table.insert(message, 0x05)
					table.merge(message, data.content)
				elseif(data.type == "datetime") then
					error('[OPACK.pack] Datetime not yet implemented.')			
				elseif(data.type == "float") then
					-- in Lua actually all numbers are float, so we will struggle here
					-- an approach to deal is using a table hard typed for that float type
					-- then, another problem is the conversion... according a lot of people its impossible
					-- without C help. The solution here maybe will work if Lua > 5.3.
					-- but still, has no support for little endians, so not sure the encoding will work properly when decoded
					-- lots of time and testing would be needed here to make this working
					table.insert(message, 0x36)


					--table.merge(message, string.pack('d', data)) -- LUA 5.3
					table.insert(message, float_to_byte(data.content))
				elseif(data.type == "rawtable") then
					-- the original implementation deal with Strings and Byte Arrays
					-- the most close to this in Lua would be a table (raw)

					local len = #data.content

					if(len <= 0x20) then
						table.insert(message, 0x70)
						table.insert(message, len)
						table.merge(message, data.content)
					elseif(len <= 0xFF) then
						table.insert(message, 0x91)
						table.merge(message, int_to_bytes(len, "little"), 1)
						table.merge(message, data.content)
					elseif(len <= 0xFFFF) then
						table.insert(message, 0x92)
						table.merge(message, int_to_bytes(len, "little"), 2)
						table.merge(message, data.content)				
					elseif(len <= 0xFFFFFF) then
						table.insert(message, 0x93)
						table.merge(message, int_to_bytes(len, "little"), 3)
						table.merge(message, data.content)			
					elseif(len <= 0xFFFFFFFF) then
						table.insert(message, 0x94)
						table.merge(message, int_to_bytes(len, "little"), 4)
						table.merge(message, data.content)
					end

				elseif(data.type == "list") then

					table.insert(message, 0xD0)
					table.insert(message, math.min(#data.content, 0xF))
					table.insert(message, '')

					for k, v in pairs(data.content) do
						table.merge(message, OPACK.pack(v, object_list))
					end

					if(#message >= 0xF) then
						table.insert(message, 0x03)
					end

				elseif(data.type == "dict") then

					table.insert(message, 0xE0)
					table.insert(message, math.min(#data.content, 0xF))
					table.insert(message, '')

					for k, v in pairs(data.content) do
						table.merge(message, OPACK.pack(k, object_list))
						table.merge(message, OPACK.pack(v, object_list))
					end

					if(#message >= 0xF) then
						table.insert(message, 0x03)
					end

				elseif(data.type == "UID") then

					if(data.content <= 0xFF) then
						table.insert(message, 0xC1)
						table.merge(message, int_to_bytes(data.content, "big"), 1)
					elseif(data.content <= 0xFFFF) then
						table.insert(message, 0xC2)
						table.merge(message, int_to_bytes(data.content, "big"), 2)
					elseif(data.content <= 0xFFFFFF) then
						table.insert(message, 0xC3)
						table.merge(message, int_to_bytes(data.content, "big"), 3)						
					elseif(data.content <= 0xFFFFFFFF) then
						table.insert(message, 0xC4)
						table.merge(message, int_to_bytes(data.content, "big"), 4)					
					end				
				end
			end 
		}

		,{ 
			condition = function(data) return type(data) == "number" end
			, callback = function(data)  

				if(data < 0x28) then
					table.insert(message, data + 8)
				elseif(data <= 0xFF) then
					table.insert(message, 0x30)
					table.merge(message, int_to_bytes(data, "little"), 1)
				elseif(data <= 0xFFFF) then
					table.insert(message, 0x31)
					table.merge(message, int_to_bytes(data, "little"), 2)						
				elseif(data <= 0xFFFFFFFF) then
					table.insert(message, 0x32)
					table.merge(message, int_to_bytes(data, "little"), 3)					
				elseif(data <= 0xFFFFFFFFFFFFFFFF) then
					table.insert(message, 0x33)
					table.merge(message, int_to_bytes(data, "little"), 4)			
				end
			end 
		}

		,{ 
			condition = function(data) return type(data) == "string" end
			, callback = function(data)  

				-- Lua doenst support any encoding/decoding from utf-8 natively in older versions
				-- the code above is for 5.3, in older versions, C or extensions must be needed

				-- in my case, I use Lua 5.2 and cant change it, so.. I just convert the string into a table

				--local encoded = utf8.char(data) -- FOR LUA 5.3+

				local t = {}

				for k,v in utf8.codes(data) do
					table.insert(t, utf8.char(v))
				end

				local encoded = t

				local len = #encoded

				if(len <= 0x20) then
					table.insert(message, 0x40)
					table.insert(message, len)
					table.merge(message, encoded)
				elseif(len <= 0xFF) then
					table.insert(message, 0x61)
					table.merge(message, int_to_bytes(len, "little"), 1)
					table.merge(message, encoded)
				elseif(len <= 0xFFFF) then
					table.insert(message, 0x62)
					table.merge(message, int_to_bytes(len, "little"), 2)
					table.merge(message, encoded)				
				elseif(len <= 0xFFFFFF) then
					table.insert(message, 0x63)
					table.merge(message, int_to_bytes(len, "little"), 3)
					table.merge(message, encoded)			
				elseif(len <= 0xFFFFFFFF) then
					table.insert(message, 0x64)
					table.merge(message, int_to_bytes(len, "little"), 4)
					table.merge(message, encoded)	
				end				
			end 
		}				
	}

	for _,c in pairs(typeConvertCallbacks) do
		if(c.condition(data)) then
			c.callback(data)
		end
	end


	if(object_list) then

		local index = string.find(message, object_list)

		if(index) then
			table.insert(message, 0xA0)
			table.insert(message, index)
		end
	end

	-- not sure why they do it on Python code, maybe a reference later
	if(#message > 1) then

		if(not object_list) then
			object_list = {}
		end

		table.merge(object_list, message)
	end

	return message
end


-- TESTING
local testData = {}

table.insert(testData, "This is a string test")
table.insert(testData, "Next will be a boolean test")
table.insert(testData, true)
table.insert(testData, false)
table.insert(testData, "Now lets put some UUID")
table.insert(testData, { type = 'UUID', content = uuid() })
table.insert(testData, "Some regular numbers")
table.insert(testData, 475)
table.insert(testData, 1655487)
table.insert(testData, -44756)
table.insert(testData, "For float we'll use P.I")
table.insert(testData, { type = 'float', content = 3.14159265359})
table.insert(testData, "Lets try Python-like List")

local myList = { "purple", "orange", "blue" }
table.insert(testData, { type = 'list', content = myList})

table.insert(testData, "And also Python-like Dictionaries")

local myDict = { 
	favorite_color = 'blue' 
	,myCountry = 'Brazil'
	,fuelToProgramming = 'Coffee'
}

table.insert(testData, { type = 'dict', content = myDict})

table.insert(testData, "Will try to put this UID type that I have no idea why it's for")
table.insert(testData, { type = 'UID', content = 457})
table.insert(testData, { type = 'UID', content = 214})
table.insert(testData, { type = 'UID', content = 885522})

local ret = {}

for k,v in pairs(testData) do 
	table.merge(ret, OPACK.pack(v))
end

print('Length: ' .. #ret)

local str = ''

for k, v in pairs(ret) do

	local byte = v

	if(type(v) == 'string') then
		str = str .. string.format('%s - ', byte)
	else
		str = str .. string.format('%x - ', byte)
	end	
end

print(str)