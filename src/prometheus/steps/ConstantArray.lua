-- ConstantArray.lua (HEAVILY MODIFIED: Closured, Calculated Index)

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local visitast = require("prometheus.visitast");
local util     = require("prometheus.util")

local AstKind = Ast.AstKind;

local ConstantArray = Step:extend();
ConstantArray.Description = "This Step Extracts all Constants and puts them into a Closured Array with an obfuscated index lookup via function calls.";
ConstantArray.Name = "Constant Array (Closured/Calculated)";

-- ... (SettingsDescriptor and boilerplate remain similar) ...

local CONST_FUNC_ID = Ast.Scope:new(nil):addVariable(); -- Unique name for the array-returning function

-- HEAVY MOD: Add array declaration inside a self-executing function
function ConstantArray:addArrayDeclaration(ast)
    local funcScope = Ast.Scope:new(self.rootScope);
    local arrVar = funcScope:addVariable(); -- Array variable is local to the closure

    local arrayInitializer = Ast.FunctionCallExpression(
        Ast.FunctionLiteralExpression({}, Ast.Block({
            -- Array declaration inside a closure
            Ast.LocalVariableDeclaration(funcScope, {arrVar}, {Ast.TableLiteralExpression(util.map(self.constants, function(c)
                return Ast.TableItemExpression(self:CreateConstantExpression(c));
            end))}),
            -- Return the array instance
            Ast.ReturnStatement({Ast.VariableExpression(funcScope, arrVar)})
        }, funcScope)),
        {}
    )
    
    -- The local function that, when called, returns the array instance
    table.insert(ast.body.statements, 1, 
        Ast.LocalFunctionDeclaration(self.rootScope, CONST_FUNC_ID, {}, Ast.Block({
            Ast.ReturnStatement({arrayInitializer})
        }, funcScope)));

end

-- HEAVY MOD: Create a wrapper function with complex index calculation
function ConstantArray:createWrapperFunction(ast)
    local funcScope = Ast.Scope:new(self.rootScope);
    self.wrapperId = self.rootScope:addVariable(); -- New variable for wrapper function
    local arrayVar = funcScope:addVariable();
    local arg = funcScope:addVariable();
    
    local offset = math.random(100, 1000);

    table.insert(ast.body.statements, 1, Ast.LocalFunctionDeclaration(self.rootScope, self.wrapperId, {
        Ast.VariableExpression(funcScope, arg)
    }, Ast.Block({
        -- 1. Call the array function to get the array instance
        Ast.LocalVariableDeclaration(funcScope, {arrayVar}, {Ast.FunctionCallExpression(Ast.VariableExpression(self.rootScope, CONST_FUNC_ID), {})}),
        
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

function ConstantArray:apply(ast)
    -- ... (rest of the apply function uses the new addArrayDeclaration and createWrapperFunction) ...
    
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
