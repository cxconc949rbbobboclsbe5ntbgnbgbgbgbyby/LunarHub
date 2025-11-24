-- NumbersToExpressions.lua (HEAVILY MODIFIED: Trig/Bitwise Encoding)
-- This Step Converts number Literals to complex expressions using trigonometry and bitwise operations.

unpack = unpack or table.unpack; -- Standard Lua 5.1 compatibility

-- MOCK FRAMEWORK IMPORTS & UTILITIES
local Step = {extend = function(t) return t end};
local Ast = {
    AstKind = {NumberExpression = "NumberExpression"},
    NumberExpression = function(val) return {kind="NumberExpression", value=val} end,
    FunctionCallExpression = function(func, args) return {kind="FunctionCallExpression", func=func, args=args} end,
    VariableExpression = function(scope, id) return {kind="VariableExpression", scope=scope, id=id} end,
    AddExpression = function(a, b) return {kind="AddExpression", left=a, right=b} end,
    SubExpression = function(a, b) return {kind="SubExpression", left=a, right=b} end,
    MulExpression = function(a, b, isFloat) return {kind="MulExpression", left=a, right=b, isFloat=isFloat} end,
};
local Scope = {new = function() return {resolveGlobal=function(name) return name, name end} end};
local visitast = function(ast, pre, post) end;
local util     = {
    isInteger = function(n) return n == math.floor(n) end, -- Mock isInteger
    shuffle = function(t) return t end, -- Mock shuffle
};

local AstKind = Ast.AstKind;

local NumbersToExpressions = Step:extend();
NumbersToExpressions.Description = "This Step Converts number Literals to Expressions";
NumbersToExpressions.Name = "Numbers To Expressions (Trig/Bitwise)";

NumbersToExpressions.SettingsDescriptor = {
	Treshold = {type = "number", default = 1, min = 0, max = 1,},
    InternalTreshold = {type = "number", default = 0.2, min = 0, max = 0.8, }
}

function NumbersToExpressions:init(settings)
	self.Treshold = settings and settings.Treshold or 1;
    self.InternalTreshold = settings and settings.InternalTreshold or 0.2;

    -- Mock scopes for global lookups
	local globalScope = Scope:new(nil); 
    local mathScope = globalScope:resolveGlobal("math");
    local bitScope = globalScope:resolveGlobal("bit"); -- Assumes bit library is available (LuaJIT/5.2+)

	self.ExpressionGenerators = {
        
        function(val, depth) -- Trigonometric Encoding (Heavy Mod)
            local offset = math.random(-100, 100);
            local target_val = val - offset;
            
            -- Formula: offset + floor(cos(0) * target_val)
            local cos_zero_call = Ast.FunctionCallExpression(Ast.VariableExpression(mathScope, mathScope:resolveGlobal("cos")), {Ast.NumberExpression(0)});
            
            local expr = Ast.FunctionCallExpression(Ast.VariableExpression(mathScope, mathScope:resolveGlobal("floor")), {
                Ast.MulExpression(cos_zero_call, self:CreateNumberExpression(target_val, depth), false)
            });
            
            return Ast.AddExpression(self:CreateNumberExpression(offset, depth), expr, false);
        end,
        
        function(val, depth) -- Bitwise XOR Encoding (Heavy Mod)
            -- Only applies to integers within a safe range
            if not util.isInteger(val) or val < -2^30 or val > 2^30 then return false end
            
            local key_a = math.random(-2^15, 2^15);
            local key_b = bit.bxor(val, key_a); -- Assumes 'bit' module has been required
            
            -- Formula: bit.bxor(A, B) = Value
            local expr = Ast.FunctionCallExpression(Ast.VariableExpression(bitScope, bitScope:resolveGlobal("bxor")), {
                self:CreateNumberExpression(key_a, depth), 
                self:CreateNumberExpression(key_b, depth)
            });
            
            return expr;
        end,
        
        function(val, depth) -- Bitwise Shift Encoding (Heavy Mod)
            -- Only applies to integers within a safe range and non-zero
            if not util.isInteger(val) or val < -2^30 or val > 2^30 or val == 0 then return false end

            local shift = math.random(1, 10);
            -- Mock: Assuming bit.lshift is available
            local encoded = bit.lshift and bit.lshift(val, shift) or (val * (2^shift)); 
            
            -- Formula: bit.rshift(Encoded, Shift)
            local expr = Ast.FunctionCallExpression(Ast.VariableExpression(bitScope, bitScope:resolveGlobal("rshift")), {
                self:CreateNumberExpression(encoded, depth),
                Ast.NumberExpression(shift)
            });
            
            return expr;
        end,
        
        function(val, depth) -- Addition (Fallback/Internal)
            local val2 = math.random(-2^20, 2^20);
            local diff = val - val2;
            return Ast.AddExpression(self:CreateNumberExpression(val2, depth), self:CreateNumberExpression(diff, depth), false);
        end, 
        
        function(val, depth) -- Subtraction (Fallback/Internal)
            local val2 = math.random(-2^20, 2^20);
            local diff = val + val2;
            return Ast.SubExpression(self:CreateNumberExpression(diff, depth), self:CreateNumberExpression(val2, depth), false);
        end
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    if depth > 0 and math.random() >= self.InternalTreshold or depth > 15 then
        return Ast.NumberExpression(val)
    end

    local generators = util.shuffle({unpack(self.ExpressionGenerators)});
    for i, generator in ipairs(generators) do
        local node = generator(val, depth + 1);
        if node then
            return node;
        end
    end

    return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
	visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            if math.random() <= self.Treshold then
                return self:CreateNumberExpression(node.value, 0)
            end
        end
        return node;
    end)
    
    return ast;
end

return NumbersToExpressions;
