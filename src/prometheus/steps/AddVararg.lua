-- AddVararg.lua (HEAVILY MODIFIED: Dummy Arguments and Vararg)
-- This Step Adds Vararg to all Functions and injects a randomized number of dummy named arguments before it.

-- MOCK FRAMEWORK IMPORTS
local Step = {extend = function(t) return t end};
local Ast = {
    AstKind = {FunctionDeclaration = "FunctionDeclaration", LocalFunctionDeclaration = "LocalFunctionDeclaration", FunctionLiteralExpression = "FunctionLiteralExpression", VarargExpression = "VarargExpression"},
    VarargExpression = function() return {kind="VarargExpression"} end,
    VariableExpression = function(scope, id) return {kind="VariableExpression", scope=scope, id=id} end,
};
local visitast = function(ast, pre, post) end;
local AstKind = Ast.AstKind;

local AddVararg = Step:extend();
AddVararg.Description = "This Step Adds Vararg to all Functions and injects a randomized number of dummy named arguments before it.";
AddVararg.Name = "Add Vararg (Dummy Args)";

function AddVararg:init(settings) end

function AddVararg:apply(ast)
	visitast(ast, nil, function(node)
        if node.kind == AstKind.FunctionDeclaration or node.kind == AstKind.LocalFunctionDeclaration or node.kind == AstKind.FunctionLiteralExpression then
            
            local has_vararg = #node.args > 0 and node.args[#node.args].kind == AstKind.VarargExpression;
            
            -- Temporarily remove vararg if present
            if has_vararg then
                table.remove(node.args);
            end

            -- HEAVY MOD: Add 1 to 5 dummy named arguments
            local num_dummies = math.random(1, 5);
            for i = 1, num_dummies do
                -- Mock: In a real system, node.body.scope:addVariable() generates a unique ID
                local dummy_var = "dummy_arg_" .. math.random(100, 999);
                
                -- Add to the arguments list
                node.args[#node.args + 1] = Ast.VariableExpression(node.body.scope, dummy_var);
                
                -- Mock: In a real system, this registers the variable as an argument
                -- node.body.scope:addVariableArgument(dummy_var); 
            end

            -- Re-add the Vararg expression
            node.args[#node.args + 1] = Ast.VarargExpression();
        end
    end)
    
    return ast;
end

return AddVararg;
