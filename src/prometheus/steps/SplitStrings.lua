-- SplitStrings.lua (HEAVILY MODIFIED: Polymorphic Concatenation)
-- This Step splits Strings using a polymorphic concatenation function with junk arguments and bitwise validation.

-- MOCK FRAMEWORK IMPORTS & UTILITIES
local Step = {extend = function(t) return t end};
local Ast = {
    AstKind = {StringExpression = "StringExpression", LocalFunctionDeclaration = "LocalFunctionDeclaration"},
    VariableExpression = function(scope, id) return {kind="VariableExpression", scope=scope, id=id} end,
    NumberExpression = function(val) return {kind="NumberExpression", value=val} end,
    StringExpression = function(val) return {kind="StringExpression", value=val} end,
    FunctionCallExpression = function(func, args) return {kind="FunctionCallExpression", func=func, args=args} end,
    IndexExpression = function(table, index) return {kind="IndexExpression", table=table, index=index} end,
    TableLiteralExpression = function(fields) return {kind="TableLiteralExpression", fields=fields} end,
    TableItemExpression = function(value) return {kind="TableItemExpression", value=value} end,
    Block = function(statements, scope) return {kind="Block", statements=statements, scope=scope} end,
    ReturnStatement = function(args) return {kind="ReturnStatement", args=args} end,
    LocalFunctionDeclaration = function(scope, id, args, body) return {kind="LocalFunctionDeclaration", scope=scope, id=id, args=args, body=body} end,
    IfStatement = function(condition, consequent, alternate) return {kind="IfStatement", condition=condition, consequent=consequent, alternate=alternate} end,
    BinaryExpression = function(left, right, op) return {kind="BinaryExpression", left=left, right=right, operator=op} end,
    LocalVariableDeclaration = function(scope, ids, values) return {kind="LocalVariableDeclaration", scope=scope, ids=ids, values=values} end,
};
local Scope = {new = function() return {addVariable=function(name) return name or "var"..math.random(1, 999) end, resolveGlobal=function(name) return name, name end, addReferenceToHigherScope=function() end} end};
local visitAst = function(ast, pre, post) end;
local util = {
    splitString = function(s, l) return {"chunk1", "chunk2"} end, -- Mock splitString
    map = function(t, f) local new_t = {}; for k,v in ipairs(t) do new_t[k] = f(v) end return new_t end, -- Mock map
    -- Mock the shuffle utility (not strictly needed but good for context)
    shuffle = function(t) return t end, 
};
local enums = {LuaVersion = {Lua51=1}}; -- Mock enums
local AstKind = Ast.AstKind;

local SplitStrings = Step:extend();
SplitStrings.Description = "This Step splits Strings to a specific or random length";
SplitStrings.Name = "Split Strings (Polymorphic)";

SplitStrings.SettingsDescriptor = {
    Treshold = {type = "number", default = 1, min = 0, max = 1,},
    MinLength = {type = "number", default = 5, min = 1, max = nil,},
    MaxLength = {type = "number", default = 5, min = 1, max = nil,},
    ConcatenationType = {
        type = "enum", values = {"operator", "table", "custom"}, default = "custom",
    },
    CustomFunctionType = {
        type = "enum", values = {"global", "local", "inline"}, default = "global",
    },
};

function SplitStrings:init(settings)
    self.ConcatenationType = settings and settings.ConcatenationType or "custom";
    self.CustomFunctionType = settings and settings.CustomFunctionType or "global";
    self.Treshold = settings and settings.Treshold or 1;
    self.MinLength = settings and settings.MinLength or 5;
    self.MaxLength = settings and settings.MaxLength or 5;
end

-- HEAVY MOD: Generate a complex concatenation function
local function generateCustomConcatenationFunction(scope, var_id)
    local funcScope = Scope:new(scope);
    
    -- Randomly name the real string arguments
    local args_real = {}
    for i=1, math.random(2, 5) do args_real[i] = funcScope:addVariable("str_part") end
    
    -- Dummy argument for polymorphic validation
    local arg_dummy = funcScope:addVariable("dummy_check"); 
    local rand_check = math.random(1, 255); -- The required bitwise check value
    
    -- JUNK: Add a randomized number of unused arguments
    local args_junk = {}
    for i=1, math.random(1, 3) do args_junk[i] = funcScope:addVariable("junk_var") end

    -- Combine arguments: Dummy, Real Chunks, Junk
    local all_args = { Ast.VariableExpression(funcScope, arg_dummy) }
    for i, v in ipairs(args_real) do table.insert(all_args, Ast.VariableExpression(funcScope, v)) end
    for i, v in ipairs(args_junk) do table.insert(all_args, Ast.VariableExpression(funcScope, v)) end
    
    local block = Ast.Block({
        -- JUNK/VALIDATION: Check the dummy argument using bitwise ops (requires bit library, assumed available)
        Ast.IfStatement(
            Ast.BinaryExpression(
                Ast.FunctionCallExpression(Ast.VariableExpression(funcScope:resolveGlobal("bit"), funcScope:resolveGlobal("band")), 
                    {Ast.VariableExpression(funcScope, arg_dummy), Ast.NumberExpression(rand_check)}),
                Ast.NumberExpression(rand_check), 
                "=="
            ),
            Ast.Block({
                -- REAL CONCATENATION: Use table.concat
                Ast.ReturnStatement({
                    Ast.FunctionCallExpression(
                        Ast.IndexExpression(Ast.VariableExpression(funcScope:resolveGlobal("table")), Ast.StringExpression("concat")),
                        {
                            Ast.TableLiteralExpression(util.map(args_real, function(id) 
                                return Ast.TableItemExpression(Ast.VariableExpression(funcScope, id));
                            end))
                        }
                    )
                })
            }),
            Ast.Block({
                -- DUMMY ERROR PATH
                Ast.ReturnStatement({Ast.StringExpression("")})
            })
        )
    }, funcScope);

    return Ast.LocalFunctionDeclaration(scope, var_id, all_args, block), args_real, rand_check;
end

function SplitStrings:apply(ast, pipeline)
    local globalScope = ast.globalScope or Scope:new();
    local concatFunctionId;
    local concatCheckValue;
    local data = {globalScope = globalScope, scope = globalScope};

    if self.ConcatenationType == "custom" and self.CustomFunctionType == "global" then
        concatFunctionId = globalScope:addVariable("string_concat_func");
        local funcDecl, _, checkVal = generateCustomConcatenationFunction(globalScope, concatFunctionId);
        concatCheckValue = checkVal;
        table.insert(ast.body.statements, 1, funcDecl);
    end

    -- MOCK AST TRAVERSAL AND REPLACEMENT
    visitAst(ast, nil, function(node, data)
        if(node.kind == AstKind.StringExpression) then
            if node.value:len() > self.MinLength and math.random() <= self.Treshold then
                local length = math.random(self.MinLength, self.MaxLength);
                local chunks = util.splitString(node.value, length); -- Mocked: {"chunk1", "chunk2"}
                local args = {};
                
                if self.ConcatenationType == "custom" and self.CustomFunctionType == "global" then
                    -- 1. Dummy argument for validation (must pass the bitwise check)
                    table.insert(args, Ast.NumberExpression(concatCheckValue));
                    
                    -- 2. Real string chunks
                    for _, chunk in ipairs(chunks) do
                        table.insert(args, Ast.StringExpression(chunk));
                    end
                    
                    -- 3. Random junk arguments
                    for i=1, math.random(1, 3) do 
                        table.insert(args, Ast.NumberExpression(math.random()))
                    end

                    data.scope:addReferenceToHigherScope(ast.globalScope, concatFunctionId);
                    node = Ast.FunctionCallExpression(Ast.VariableExpression(ast.globalScope, concatFunctionId), args);
                    return node, true;
                end
                -- Other concatenation types would go here
            end
        end
        
        return node;
    end, data)
    
    return ast;
end

return SplitStrings;
