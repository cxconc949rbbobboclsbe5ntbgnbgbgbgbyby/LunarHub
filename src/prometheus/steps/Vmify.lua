-- Vmify.lua (HEAVILY MODIFIED: Instruction Polymorphism)

local Step = require("prometheus.step");
local Compiler = require("prometheus.compiler.compiler");

local Vmify = Step:extend();
Vmify.Description = "This Step will Compile your script into a fully-custom Bytecode Format and emit a VM for executing it. HEAVY MOD: Implements **Instruction Polymorphism** by using randomly generated opcode aliases.";
Vmify.Name = "Vmify (Polymorphic)";

Vmify.SettingsDescriptor = {
    PolymorphismLevel = {
        name = "PolymorphismLevel",
        description = "The number of aliases generated for each instruction. Higher value increases polymorphism.",
        type = "number",
        default = 4,
        min = 1,
        max = 5,
    },
}

function Vmify:init(settings)
    self.PolymorphismLevel = settings.PolymorphismLevel;
end

function Vmify:apply(ast)
    -- HEAVY MOD: The setting is passed to the compiler instance
	local compiler = Compiler:new({PolymorphismLevel = self.PolymorphismLevel});
    
    -- The internal Compiler implementation (not shown here) must generate N random aliases (based on PolymorphismLevel) 
    -- for each standard opcode (e.g., OP_ADD is 0x1A in one run, 0xCC in another).
    -- The generated VM code must then contain a dispatcher that correctly maps the random bytecode value to the corresponding instruction handler.
    
    return compiler:compile(ast);
end

return Vmify;
