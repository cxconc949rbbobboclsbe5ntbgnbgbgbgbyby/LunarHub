-- ConstantArray.lua (HEAVILY MODIFIED: Closured, Calculated Index)
-- This Step Extracts all Constants and puts them into a Closured Array with an obfuscated index lookup via function calls.

-- MOCK FRAMEWORK IMPORTS & UTILITIES
local Step = {extend = function(t) return t end};
local Ast = {
    AstKind = {NumberExpression = "NumberExpression"},
    FunctionLiteralExpression = function(args, body) return {kind="FunctionLiteralExpression", args=args, body=body} end,
    FunctionCallExpression = function(func, args) return {kind="FunctionCallExpression", func=func, args=args} end,
    Block = function(statements, scope) return {kind="Block", statements=statements, scope=scope} end,
    ReturnStatement = function(args) return {kind="ReturnStatement", args=args} end,
    LocalVariableDeclaration = function(scope, ids, values) return {kind="LocalVariableDeclaration", scope=scope, ids=ids, values=values} end,
    VariableExpression = function(scope, id) return {kind="VariableExpression", scope=scope, id=id} end,
    NumberExpression = function(val) return {kind="NumberExpression", value=val} end,
    TableLiteralExpression = function(fields) return {kind="TableLiteralExpression", fields=fields} end,
    TableItemExpression = function(value) return {kind="TableItemExpression", value=value} end,
    IndexExpression = function(table, index) return {kind="IndexExpression", table=table, index=index} end,
    AddExpression = function(a, b) return {kind="AddExpression", left=a, right=b} end,
    SubExpression = function(a, b) return {kind="SubExpression", left=a, right=b} end,
    Comment = function(val) return {kind="Comment", value=val} end,
};
local Scope = {new = function() return {addVariable=function(name) return name or "var"..math.random(1, 999) end, resolveGlobal=function(name) return name, name end, addReferenceToHigherScope=function() end} end};
local visitast = function(ast, pre, post) end;
local util     = {
    map = function(t, f) local new_t = {}; for k,v in ipairs(t) do new_t[k] = f(v) end return new_t end,
    shuffle = function(t) return t end, -- Mock shuffle
    rotate = function(t, s) end, -- Mock rotate
};

local AstKind = Ast.AstKind;

local ConstantArray = Step:extend();
ConstantArray.Description = "This Step Extracts all Constants and puts them into a Closured Array with an obfuscated index lookup via function calls.";
ConstantArray.Name = "Constant Array (Closured/Calculated)";

-- MOCK ID for the array-returning function
local CONST_FUNC_ID = "get_const_array_closure"; 

function ConstantArray:init(settings)
    self.constants = {"Hello", 10, true, "World"}; -- Mock constants
    self.rootScope = Scope:new();
    self.wrapperId = "get_const_wrapper";
    self.Rotate = settings and settings.Rotate or false;
end

-- Mock function to create the AST node for a constant value
function ConstantArray:CreateConstantExpression(constant)
    if type(constant) == "string" then return Ast.StringExpression(constant) end
    if type(constant) == "number" then return Ast.NumberExpression(constant) end
    return Ast.VariableExpression(self.rootScope:resolveGlobal("true"))
end

-- HEAVY MOD: Add array declaration inside a self-executing closure function
function ConstantArray:addArrayDeclaration(ast)
    local funcScope = Ast.Scope:new(self.rootScope);
    local arrVar = funcScope:addVariable("const_arr_instance"); -- Array variable is local to the closure

    local arrayInitializer = Ast.FunctionCallExpression(
        Ast.FunctionLiteralExpression({}, Ast.Block({
            -- Array declaration inside a closure
            Ast.LocalVariableDeclaration(funcScope, {Ast.VariableExpression(funcScope, arrVar)}, {Ast.TableLiteralExpression(util.map(self.constants, function(c)
                return Ast.TableItemExpression(self:CreateConstantExpression(c));
            end))}),
            -- Return the array instance
            Ast.ReturnStatement({Ast.VariableExpression(funcScope, arrVar)})
        }, funcScope)),
        {}
    )
    
    -- The local function that, when called, returns the array instance
    table.insert(ast.body.statements, 1, 
        Ast.FunctionLiteralExpression({}, Ast.Block({
            Ast.ReturnStatement({arrayInitializer})
        }, funcScope)));
end

-- HEAVY MOD: Create a wrapper function with complex index calculation
function ConstantArray:createWrapperFunction(ast)
    local funcScope = Ast.Scope:new(self.rootScope);
    self.wrapperId = funcScope:addVariable("const_getter"); -- New variable for wrapper function
    local arrayVar = funcScope:addVariable("arr_ref");
    local arg = funcScope:addVariable("idx");
    
    local offset = math.random(100, 1000);

    table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(self.rootScope, {Ast.VariableExpression(self.rootScope, self.wrapperId)}, Ast.FunctionLiteralExpression({
        Ast.VariableExpression(funcScope, arg)
    }, Ast.Block({
        -- 1. Call the array closure function to get the array instance
        Ast.LocalVariableDeclaration(funcScope, {Ast.VariableExpression(funcScope, arrayVar)}, {Ast.FunctionCallExpression(Ast.VariableExpression(self.rootScope, CONST_FUNC_ID), {})}),
        
        -- 2. Index calculation: (index - offset) + math.floor(math.cos(0)) + offset
        local index_calc = Ast.AddExpression(
            Ast.SubExpression(Ast.VariableExpression(funcScope, arg), Ast.NumberExpression(offset)),
            Ast.FunctionCallExpression(
                Ast.VariableExpression(funcScope:resolveGlobal("math"), funcScope:resolveGlobal("floor")), 
                {
                    Ast.FunctionCallExpression(Ast.VariableExpression(funcScope:resolveGlobal("math"), funcScope:resolveGlobal("cos")), {Ast.NumberExpression(0)})
                }
            )
        );
        index_calc = Ast.AddExpression(index_calc, Ast.NumberExpression(offset));
        
        -- 3. Final return
        Ast.ReturnStatement({
            Ast.IndexExpression(
                Ast.VariableExpression(funcScope, arrayVar),
                index_calc
            )
        });
    }, funcScope)));
end

-- Mock implementation of rotation code injection
function ConstantArray:addRotateCode(ast, shift)
    table.insert(ast.body.statements, 1, Ast.Comment("Rotation code for shift " .. shift .. " added."));
end

function ConstantArray:replaceConstantsWithWrapper(ast)
    local wrapperCallIndex = function(i)
        return Ast.FunctionCallExpression(Ast.VariableExpression(self.rootScope, self.wrapperId), {Ast.NumberExpression(i)});
    end
    
    visitast(ast, nil, function(node)
        if node.kind == AstKind.NumberExpression and node.value == 10 then
            return wrapperCallIndex(2); -- Replace 10 (index 2 in constants array)
        end
    end)
end


function ConstantArray:apply(ast)
    -- Initialize root body (for mock purposes)
    ast.body = ast.body or Ast.Block({}, self.rootScope);
    
    -- Mock: Create the function ID for the closure getter
    self.rootScope:addVariable(CONST_FUNC_ID);

    local steps = util.shuffle({
		function() self:addArrayDeclaration(ast); end,
		function() self:createWrapperFunction(ast); end,
		function() self:replaceConstantsWithWrapper(ast); end,
		function()
			if self.Rotate and #self.constants > 1 then
				local shift = math.random(1, #self.constants - 1);
				util.rotate(self.constants, -shift);
				self:addRotateCode(ast, shift);
			end
		end,
	});

	for i, f in ipairs(steps) do
		f();
	end

    return ast;
end

return ConstantArray;
