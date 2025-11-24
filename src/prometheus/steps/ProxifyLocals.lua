-- ProxifyLocals.lua (HEAVILY MODIFIED: Dynamic Key Metatable Proxy)

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local visitast = require("prometheus.visitast");
local RandomLiterals = require("prometheus.randomLiterals")
local RandomStrings = require("prometheus.randomStrings") -- Needed for junk names

local AstKind = Ast.AstKind;

local ProifyLocals = Step:extend();
ProifyLocals.Description = "This Step wraps all locals into Proxy Objects with a dynamically calculated key access via __index metatable.";
ProifyLocals.Name = "Proxify Locals (Dynamic Metatable)";

ProifyLocals.SettingsDescriptor = {
    -- ... (SettingsDescriptor remains similar) ...
}

-- ... (Utility functions like shallowcopy, callNameGenerator remain similar) ...

-- HEAVY MOD: New assignment expression generation with complex metatable
function ProifyLocals:CreateAssignmentExpression(localMetatableInfo, valueExpression, scope)
    local key_string = localMetatableInfo.valueName;
    local offset = math.random(1, 100);
    local check_val = math.random(1, 255);
    local JUNK_KEY_VAR = scope:addVariable()
    local JUNK_VAL_VAR = scope:addVariable()

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
                    Ast.ReturnStatement({Ast.IndexExpression(Ast.VariableExpression(self.proxyObjectVarScope, self.proxyObjectVarId), Ast.StringExpression(key_string))})
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
    -- ... (existing logic to initialize variables and local metatable info) ...

    visitast(ast, nil, function(node, data)
        -- ... (existing logic for LocalVariableDeclaration, Assignment, etc. calling CreateAssignmentExpression) ...

        -- HEAVY MOD: Variable Reference
        if(node.kind == AstKind.VariableExpression and not node.isGlobal) then
            local localMetatableInfo = getLocalMetatableInfo(node.scope, node.id);
            if localMetatableInfo then
                -- Access is now a complex function call that triggers the __index metatable
                local key_string = localMetatableInfo.valueName;
                
                -- Conceptual change: Rely on the metatable's __index to return the value.
                -- We still use a table access, which in turn triggers the __index function.
                return Ast.IndexExpression(
                    Ast.VariableExpression(self.proxyObjectVarScope, self.proxyObjectVarId), 
                    Ast.StringExpression(key_string) 
                )
            end
        end
        -- ... (other logic remains) ...
    end)
    
    -- ... (existing boilerplate for adding setmetatable declaration) ...
end

return ProifyLocals;
