-- SplitStrings.lua (HEAVILY MODIFIED: Polymorphic Concatenation)

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local visitAst = require("prometheus.visitast");
local Parser = require("prometheus.parser");
local util = require("prometheus.util");
local enums = require("prometheus.enums")

local LuaVersion = enums.LuaVersion;
local AstKind = Ast.AstKind;

local SplitStrings = Step:extend();
SplitStrings.Description = "This Step splits Strings using a polymorphic concatenation function with junk arguments and bitwise validation.";
SplitStrings.Name = "Split Strings (Polymorphic)";

-- ... (SettingsDescriptor remains similar) ...

-- HEAVY MOD: Generate a complex concatenation function
local function generateCustomConcatenationFunction(scope, var_id)
    local funcScope = Scope:new(scope);
    
    -- Randomly name the real string arguments
    local args_real = {}
    for i=1, math.random(2, 5) do args_real[i] = funcScope:addVariable() end
    
    -- Dummy argument for polymorphic validation
    local arg_dummy = funcScope:addVariable(); 
    local rand_check = math.random(1, 255); -- The required bitwise check value
    
    -- JUNK: Add a randomized number of unused arguments
    local args_junk = {}
    for i=1, math.random(1, 3) do args_junk[i] = funcScope:addVariable() end

    -- Combine arguments: Dummy, Real Chunks, Junk
    local all_args = { Ast.VariableExpression(funcScope, arg_dummy) }
    for i, v in ipairs(args_real) do table.insert(all_args, Ast.VariableExpression(funcScope, v)) end
    for i, v in ipairs(args_junk) do table.insert(all_args, Ast.VariableExpression(funcScope, v)) end
    
    local block = Ast.Block({
        -- JUNK/VALIDATION: Check the dummy argument using bitwise ops
        Ast.IfStatement(
            Ast.BinaryExpression(
                Ast.FunctionCallExpression(Ast.VariableExpression(funcScope:resolveGlobal("bit"), funcScope:resolveGlobal("band")), 
                    {Ast.VariableExpression(funcScope, arg_dummy), Ast.NumberExpression(rand_check)}),
                Ast.NumberExpression(rand_check), 
                "=="
            ),
            Ast.Block({
                -- REAL CONCATENATION
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
    -- ... (existing boilerplate) ...
    
    local concatFunctionId;
    local concatCheckValue;
    
    if self.ConcatenationType == "custom" and self.CustomFunctionType == "global" then
        local globalScope = ast.globalScope;
        concatFunctionId = globalScope:addVariable();
        local funcDecl, _, checkVal = generateCustomConcatenationFunction(globalScope, concatFunctionId);
        concatCheckValue = checkVal;
        table.insert(ast.body.statements, 1, funcDecl);
    end

    -- ... (traversal logic) ...

    visitAst(ast, nil, function(node, data)
        -- ... (existing logic to check treshold) ...
        
        local chunks = util.splitString(node.value, length);
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

        -- ... (existing logic for other concatenation types) ...

    end, data)
    
    return ast;
end

return SplitStrings;
