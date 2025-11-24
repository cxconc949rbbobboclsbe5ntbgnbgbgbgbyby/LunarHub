-- ProxifyLocals.lua (HEAVILY MODIFIED: Dynamic Key Metatable Proxy)
-- This Step wraps all locals into Proxy Objects with a dynamically calculated key access via __index metatable.

-- MOCK FRAMEWORK IMPORTS & UTILITIES
local Step = {extend = function(t) return t end};
local Ast = {
    AstKind = {VariableExpression = "VariableExpression", LocalVariableDeclaration = "LocalVariableDeclaration", Assignment = "Assignment"},
    TableLiteralExpression = function(fields) return {kind="TableLiteralExpression", fields=fields} end,
    TableKeyAssignment = function(key, value) return {kind="TableKeyAssignment", key=key, value=value} end,
    StringExpression = function(val) return {kind="StringExpression", value=val} end,
    NumberExpression = function(val) return {kind="NumberExpression", value=val} end,
    FunctionLiteralExpression = function(args, body) return {kind="FunctionLiteralExpression", args=args, body=body} end,
    Block = function(statements, scope) return {kind="Block", statements=statements, scope=scope} end,
    LocalVariableDeclaration = function(scope, ids, values) return {kind="LocalVariableDeclaration", scope=scope, ids=ids, values=values} end,
    FunctionCallExpression = function(func, args) return {kind="FunctionCallExpression", func=func, args=args} end,
    ReturnStatement = function(args) return {kind="ReturnStatement", args=args} end,
    IndexExpression = function(table, index) return {kind="IndexExpression", table=table, index=index} end,
    NilExpression = function() return {kind="NilExpression"} end,
    VariableExpression = function(scope, id) return {kind="VariableExpression", scope=scope, id=id, isGlobal=false} end,
    AddExpression = function(a, b) return {kind="AddExpression", left=a, right=b} end,
    IfStatement = function(condition, consequent, alternate) return {kind="IfStatement", condition=condition, consequent=consequent, alternate=alternate} end,
    BinaryExpression = function(left, right, op) return {kind="BinaryExpression", left=left, right=right, operator=op} end,
};
local Scope = {new = function() return {addVariable=function(name) return name or "var"..math.random(1, 999) end, resolveGlobal=function(name) return name, name end} end};
local visitast = function(ast, pre, post) end; -- Mock visitast
local RandomStrings = {randomString = function() return "JUNK_"..math.random(100, 999) end} -- Mock RandomStrings
local AstKind = Ast.AstKind;

local ProifyLocals = Step:extend();
ProifyLocals.Description = "This Step wraps all locals into Proxy Objects with a dynamically calculated key access via __index metatable.";
ProifyLocals.Name = "Proxify Locals (Dynamic Metatable)";

-- MOCK HELPER FUNCTIONS (needed for context)
local function getLocalMetatableInfo(scope, id)
    -- Conceptual check: returns info for variables that should be proxified
    return {valueName = "proxified_val_"..id};
end

local function shallowcopy(orig) return {} end

function ProifyLocals:init(settings)
    -- Mock variables for tracking the setmetatable global/proxy object reference
    self.setMetatableVarId = "setmetatable_func_id";
    self.setMetatableVarScope = Scope:new();
    self.proxyObjectVarId = "local_proxy_table";
    self.proxyObjectVarScope = Scope:new();
end

-- HEAVY MOD: New assignment expression generation with complex metatable
function ProifyLocals:CreateAssignmentExpression(localMetatableInfo, valueExpression, scope)
    local key_string = localMetatableInfo.valueName;
    local offset = math.random(1, 100);
    local check_val = math.random(1, 255);
    local JUNK_KEY_VAR = scope:addVariable("key_arg")
    local JUNK_VAL_VAR = scope:addVariable("calc_val")
    
    local globalScope = scope:resolveGlobal and scope or Scope:new() -- Mock global scope access

    -- 1. The internal proxy table: {[key_string] = valueExpression}
    local proxyTableLiteral = Ast.TableLiteralExpression({
        Ast.TableKeyAssignment(Ast.StringExpression(key_string), valueExpression)
    });
    
    -- 2. The __index metatable function (The core logic)
    local keyCalcLiteral = Ast.FunctionLiteralExpression({Ast.VariableExpression(scope, JUNK_KEY_VAR)}, 
        Ast.Block({
            -- JUNK CHECK: A simple calculation to ensure the metatable is not directly replaced
            Ast.LocalVariableDeclaration(scope, {Ast.VariableExpression(scope, JUNK_VAL_VAR)}, 
                {Ast.AddExpression(Ast.NumberExpression(offset), Ast.NumberExpression(check_val))}),
            Ast.IfStatement(Ast.BinaryExpression(Ast.VariableExpression(scope, JUNK_VAL_VAR), Ast.NumberExpression(offset + check_val), "=="),
                Ast.Block({
                    -- REAL ACCESS: Return the value from the internal table using the real key
                    -- Assumes the proxy object itself is named self.proxyObjectVarId
                    Ast.ReturnStatement({Ast.IndexExpression(
                        Ast.VariableExpression(self.proxyObjectVarScope, self.proxyObjectVarId), 
                        Ast.StringExpression(key_string)
                    )})
                }),
                Ast.Block({
                    Ast.ReturnStatement({Ast.NilExpression()})
                })
            )
        }, scope)
    );

    -- 3. The metatable
    local metatableLiteral = Ast.TableLiteralExpression({
        Ast.TableKeyAssignment(Ast.StringExpression("__index"), keyCalcLiteral),
        Ast.TableKeyAssignment(Ast.StringExpression(RandomStrings.randomString()), Ast.NumberExpression(math.random())) -- Junk entry
    });

    -- 4. The final expression: setmetatable({...}, {...})
    return Ast.FunctionCallExpression(
        Ast.VariableExpression(self.setMetatableVarScope, self.setMetatableVarId),
        {proxyTableLiteral, metatableLiteral}
    )
end

function ProifyLocals:apply(ast)
    -- Mock: In a real implementation, this would track the proxy table declaration
    -- and ensure all variable references are replaced.
    
    -- Mock: Add Setmetatable Variable Declaration (assuming setmetatable is global)
    table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(self.setMetatableVarScope, {Ast.VariableExpression(self.setMetatableVarScope, self.setMetatableVarId)}, {
        Ast.VariableExpression(self.setMetatableVarScope:resolveGlobal("setmetatable"))
    }));

    -- Mock: Set up the proxy object variable declaration
    table.insert(ast.body.statements, 2, Ast.LocalVariableDeclaration(self.proxyObjectVarScope, {Ast.VariableExpression(self.proxyObjectVarScope, self.proxyObjectVarId)}, {
        Ast.TableLiteralExpression({}) -- Initial empty table
    }));
    
    -- MOCK AST TRAVERSAL AND REPLACEMENT
    visitast(ast, nil, function(node, data)
        if(node.kind == AstKind.LocalVariableDeclaration) then
            -- Pretend to handle a declaration of variable 'test_local'
            local id = "test_local";
            if node.ids[1] and node.ids[1].id == id then
                local localMetatableInfo = getLocalMetatableInfo(node.scope, id);
                if localMetatableInfo then
                    local newExpr = self:CreateAssignmentExpression(localMetatableInfo, node.values[1], node.scope);
                    -- Replace the declaration with the proxied expression
                    -- This is conceptual; real logic is complex
                    return Ast.LocalVariableDeclaration(node.scope, {Ast.VariableExpression(node.scope, id)}, {newExpr});
                end
            end
        end

        -- HEAVY MOD: Variable Reference replacement (Conceptual)
        if(node.kind == AstKind.VariableExpression and not node.isGlobal) then
            local localMetatableInfo = getLocalMetatableInfo(node.scope, node.id);
            if localMetatableInfo then
                local key_string = localMetatableInfo.valueName;
                
                -- Conceptual change: Access is now via table index, which triggers the __index metatable
                return Ast.IndexExpression(
                    Ast.VariableExpression(self.proxyObjectVarScope, self.proxyObjectVarId), 
                    Ast.StringExpression(key_string) 
                )
            end
        end
    end)
    
    return ast;
end

return ProifyLocals;
