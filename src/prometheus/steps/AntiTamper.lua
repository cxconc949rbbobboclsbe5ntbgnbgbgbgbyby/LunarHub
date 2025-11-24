-- AntiTamper.lua (HEAVILY MODIFIED: Environment/Silent Fail Check)
-- This Step Breaks your Script when it is modified by checking for environment and causing a silent runtime failure.

-- MOCK FRAMEWORK IMPORTS & UTILITIES
local Step = {extend = function(t) return t end};
local Ast = {Block = function(s, scope) return {kind="Block", statements=s, scope=scope} end};
local Scope = {new = function() return {} end};
local RandomStrings = {randomString = function() return "RS_"..math.random(100, 999) end} -- Mock RandomStrings
local Parser = {new = function() return {parse = function(code) return {body={statements={
    {kind="Comment", value="-- ANTI-TAMPER INJECTION: " .. code}
}} end} end}; -- Mock Parser
local Enums = {LuaVersion = {Lua51=1}};
local logger = {warn = function(msg) print("WARNING: " .. msg) end};

local AntiTamper = Step:extend();
AntiTamper.Description = "This Step Breaks your Script when it is modified by checking for environment and causing a silent runtime failure.";
AntiTamper.Name = "Anti Tamper (Silent Fail)";

AntiTamper.SettingsDescriptor = {
    UseDebug = {
        type = "boolean",
        default = true,
        description = "Use debug library. (Recommended, however scripts will not work without debug library.)"
    }
}

function AntiTamper:init(settings)
    self.UseDebug = settings and settings.UseDebug or true;
end

function AntiTamper:apply(ast, pipeline)
    if pipeline and pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name));
        return ast;
    end
    
	local code = "do local valid = true; local env_check = true;";
    
    local JUNK_ERROR_FUNC = RandomStrings.randomString();

    -- HEAVY MOD: Add Silent-Fail Environment Check (Lua code snippet)
    local silent_fail_code = [[
        
        -- Check for common debug/environment analysis tools that indicate tampering
        if debug then
            -- Check for getinfo to see if the script is being inspected
            if debug.getinfo(1, "S") and debug.getinfo(1, "S").what == "C" then 
                env_check = false; -- Possibly running in a compiled/modified/deobfuscated environment
            end
        end
        
        -- Use standard Lua functions for checking environment state
        -- getfenv is deprecated in 5.2+, but useful for 5.1/older
        if getfenv then
            local fenv = getfenv();
            -- If critical globals are exposed or missing (e.g., setfenv is present)
            if fenv.debug or fenv.getfenv or fenv.setfenv or type(fenv.select) ~= "function" then
                env_check = false; -- Environment tampering detected
            end
        end
        
        -- Function to cause a silent failure later in the script
        local function ]] .. JUNK_ERROR_FUNC .. [[(...) 
            local val = (select('#', ...) or 0) * 3.14159; -- Arbitrary complex calculation
            -- Returns a failure value instead of erroring
            return false, "Runtime Failure Code: " .. val; 
        end

        -- If environment check fails, overwrite a critical global function with the junk function
        if not env_check then
            -- Overwrite functions crucial for control flow/data access to cause silent breakage
            _G.pcall = ]] .. JUNK_ERROR_FUNC .. [[;
            _G.select = ]] .. JUNK_ERROR_FUNC .. [[;
            _G.rawget = ]] .. JUNK_ERROR_FUNC .. [[;
        end
        
        -- Dummy call to prevent dead code elimination (must be outside the function definition)
        -- print("AntiTamper JUNK:" .. ]] .. JUNK_ERROR_FUNC .. [[(10, 20)); 
    ]];

    code = code .. silent_fail_code;
    
    -- Existing Anti-Tamper Logic (simplified)
    code = code .. [[
    valid = valid and env_check; -- Incorporate new check
    if valid then else
        -- HEAVY MOD: Instead of simple return, insert a random error with a random traceback level
        local function err_loop() 
            local rand_msg = "Critical Tamper State " .. math.random(1, 100);
            error(rand_msg, math.random(1, 10));
        end
        err_loop();
        return;
    end
end
    -- Anti Function Arg Hook (existing code remains, adjusted to use new junk function)
    local obj = setmetatable({}, {
        __tostring = function() return "Tamper Check Active" end,
        __index = function() return ]] .. JUNK_ERROR_FUNC .. [[ end,
    });
    obj[math.random(1, 100)] = obj;
    (function() end)(obj);

    ]] .. (self.UseDebug and "repeat until valid;" or "") .. [[
    ]];

    -- Parse and inject the code block
    local parsed = Parser:new({LuaVersion = Enums.LuaVersion.Lua51;}):parse(code);
    
    -- Insert the statements at the beginning of the AST body
    for i, stmt in ipairs(parsed.body.statements) do
        table.insert(ast.body.statements, i, stmt);
    end
    
    return ast;
end

return AntiTamper;
