-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- EncryptStrings.lua
--
-- This Script provides a Simple Obfuscation Step that encrypts strings
--
-- HEAVILY MODIFIED: New encryption uses a complex, dynamic poly-shift cipher.
-- The decryption routine is wrapped in a self-initializing, heavily-obfuscated function
-- with multiple junk operations to frustrate static analysis.

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")
local visitast = require("prometheus.visitast");
local util     = require("prometheus.util")
local AstKind = Ast.AstKind;

local EncryptStrings = Step:extend()
EncryptStrings.Description = "This Step will encrypt strings within your Program using a dynamic poly-shift cipher."
EncryptStrings.Name = "Encrypt Strings (Heavy Mod)"

EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings) end

-- Generates a 64-bit random seed
local function gen_complex_seed()
    return math.random(1, 2^32) * 2^32 + math.random(1, 2^32)
end

-- Generates a complex, non-linear pseudo-random byte based on state_45 and state_8
local function gen_pseudo_random_byte(state_45, state_8, param_mul_45, param_add_45, param_mul_8)
    state_45 = (state_45 * param_mul_45 + param_add_45) % 35184372088832 -- 45-bit state update
    repeat
        state_8 = state_8 * param_mul_8 % 257 -- 8-bit state update
    until state_8 ~= 1
    
    local r = state_8 % 32
    local n = math.floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r
    
    -- Combine and return a byte (0-255)
    return (math.floor(n * 256) + state_8) % 256, state_45, state_8
end


function EncryptStrings:CreateEncrypionService()
	local usedSeeds = {};

	local param_mul_45 = math.random(1, 4) * 4 + 1
	local param_add_45 = math.random(1, 17592186044415) * 2 + 1
	local param_mul_8 = (function() -- Obfuscated prime root lookup
		local g, m, d = 1, 128, math.random(0, 127) * 2 + 1
		repeat
			g, m, d = g * g * (d >= m and 3 or 1) % 257, m / 2, d % m
		until m < 1
		return g
	end)()
    local secret_key_8 = math.random(0, 255); -- Base shift/key

	local function encrypt(str)
		local seed = gen_complex_seed();
		local len = string.len(str)
		local out = {}
		local state_45 = seed % 35184372088832
        local state_8 = seed % 255 + 2

        -- Dynamic poly-shift key derived from seed
        local shift_key = {}
        for i = 1, 16 do
            local next_byte, s45, s8 = gen_pseudo_random_byte(state_45, state_8, param_mul_45, param_add_45, param_mul_8)
            state_45, state_8 = s45, s8
            shift_key[i] = next_byte
        end
        local current_key_idx = 1
        local prevVal = secret_key_8;
        
		for i = 1, len do
			local byte = string.byte(str, i);
            local key_byte = shift_key[current_key_idx] or shift_key[1]
            
            -- Complex encryption: (Byte XOR Key_Byte) ADD Shift_Key(i) MOD 256
            local encrypted_byte = (bit.bxor(byte, key_byte) + prevVal) % 256
            
			out[i] = string.char(encrypted_byte);
			prevVal = encrypted_byte; -- Chained value
            current_key_idx = (current_key_idx % 16) + 1
		end
        
        usedSeeds[seed] = true; -- Track used seeds
		return table.concat(out), seed;
	end

	local function genCode()
        -- Inject a dummy function and a junk loop before the real decoder
        local JUNK_CODE_1 = RandomStrings.randomString();
        local JUNK_CODE_2 = RandomStrings.randomString();
        
		local code = [[ 
do 
    local floor = math.floor 
    local char = string.char
    local byte = string.byte
    local len  = string.len
    local sub  = string.sub
    local bit  = bit
    local unpkg = table.unpack or unpack
    
    local DECRYPT_REAL;

    -- JUNK: Decoy function with confusing parameters
    local function ]] .. JUNK_CODE_1 .. [[ (x, y)
        local a = 0;
        for i = 1, 10 do a = (a + math.random(1, i)) % 256 end
        if x > y then a = a + x/y else a = a - y/x end
        return a + math.random(1, 100);
    end

    -- Core Runtime Logic (Self-initializing via chained functions)
    local function decrypt_init_A(seed)
        local state_45 = seed % 35184372088832
        local state_8 = seed % 255 + 2
        local param_mul_45 = ]] .. param_mul_45 .. [[
        local param_add_45 = ]] .. param_add_45 .. [[
        local param_mul_8 = ]] .. param_mul_8 .. [[
        local shift_key = {}

        -- JUNK: Confusing array fill with a useless value
        local junk_fill = {}
        for i = 1, 20 do junk_fill[i] = ]] .. JUNK_CODE_2 .. [[ end

        local function gen_prng_byte(s45, s8)
            s45 = (s45 * param_mul_45 + param_add_45) % 35184372088832
            repeat
                s8 = s8 * param_mul_8 % 257
            until s8 ~= 1
            local r = s8 % 32
            local n = floor(s45 / 2 ^ (13 - (s8 - r) / 32)) % 2 ^ 32 / 2 ^ r
            return (floor(n * 256) + s8) % 256, s45, s8
        end

        -- Derive Shift Key for Poly-Shift Cipher
        for i = 1, 16 do
            local next_byte, s45, s8 = gen_prng_byte(state_45, state_8)
            state_45, state_8 = s45, s8
            shift_key[i] = next_byte
        end

        return shift_key
    end

    -- The actual decryption routine, called after initialization
    local function decrypt_routine(str, shift_key)
        local len = len(str)
        local out = {}
        local current_key_idx = 1
        local prevVal = ]] .. secret_key_8 .. [[
        
        for i = 1, len do
            local encrypted_byte = byte(str, i)
            local key_byte = shift_key[current_key_idx] or shift_key[1]
            
            -- Reverse complex encryption: (Byte - PrevVal + 256) XOR Key_Byte MOD 256
            local original_byte = bit.bxor((encrypted_byte - prevVal + 256) % 256, key_byte)
            
            out[i] = char(original_byte);
            prevVal = encrypted_byte; -- Chained value is the encrypted byte
            current_key_idx = (current_key_idx % 16) + 1
        end

        return table.concat(out)
    end
    
    -- The externally-facing decryption function (DECRYPT)
    local function DECRYPT(str, seed)
        local shift_key = decrypt_init_A(seed)
        return decrypt_routine(str, shift_key)
    end

    local STRINGS = {}

    -- JUNK: Decoy variable access
    local a = ]] .. JUNK_CODE_1 .. [[(10, 5)

    -- Return function and string table
    return DECRYPT, STRINGS
end]]
		return code;
	end

	return {
		encrypt = encrypt,
		genCode = genCode,
	}
end

function EncryptStrings:apply(ast, pipeline)
    -- ... (rest of the apply function remains the same, but uses the new Encryptor) ...
    local Encryptor = self:CreateEncrypionService()

    local newAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51; }):parse(Encryptor.genCode());
    local doStat = newAst.body.statements[1];
    
    local scope = Ast.Scope:new(ast.body.scope);
    local decryptVar = scope:addVariable();
    local stringsVar = scope:addVariable();

    doStat.body.scope:setParent(ast.body.scope);

    visitast(newAst, nil, function(node, data)
        if(node.kind == AstKind.VariableExpression or node.kind == AstKind.AssignmentVariable or node.kind == AstKind.AssignmentIndexing) then
            if(node.scope:getVariableName(node.id) == "DECRYPT") then
                data.scope:removeReferenceToHigherScope(node.scope, node.id);
                data.scope:addReferenceToHigherScope(scope, decryptVar);
                node.scope = scope;
                node.id    = decryptVar;
            elseif(node.scope:getVariableName(node.id) == "STRINGS") then
                data.scope:removeReferenceToHigherScope(node.scope, node.id);
                data.scope:addReferenceToHigherScope(scope, stringsVar);
                node.scope = scope;
                node.id    = stringsVar;
            end
        end
    end)

    table.insert(ast.body.statements, 1, doStat);
    
    visitast(ast, nil, function(node, data)
        if(node.kind == AstKind.StringExpression) then
            data.scope:addReferenceToHigherScope(scope, stringsVar);
            data.scope:addReferenceToHigherScope(scope, decryptVar);
            local encrypted, seed = Encryptor.encrypt(node.value);
            return Ast.IndexExpression(
                Ast.VariableExpression(scope, stringsVar), 
                Ast.FunctionCallExpression(Ast.VariableExpression(scope, decryptVar), {
                    Ast.StringExpression(encrypted), 
                    Ast.NumberExpression(seed),
                    Ast.NumberExpression(string.len(encrypted))
                })
            );
        end
        return node, false;
    end);
	
	return ast;
end

return EncryptStrings;
