const express = require('express');
const crypto = require('crypto');
const cors = require('cors');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

// --- Middleware Setup ---
// CRITICAL: Increased payload limit for large scripts
app.use(express.json({ limit: '100mb' }));
app.use(express.urlencoded({ limit: '100mb', extended: true }));
app.use(cors());
// Serves files from the 'public' directory
app.use(express.static('public'));

// --- Obfuscation Constants ---
const WATERMARK = "--[[ </> discord.gg/V49Pcq4dDy @SlayersonV4 ]] ";
const FALLBACK_WATERMARK = "--[[ OBFUSCATION FAILED: Returning raw script. Check your Lua syntax. ]] ";
// Path to the external Lua obfuscator CLI (assuming 'src/cli.lua')
const SCRIPT_LUA_PATH = path.join(__dirname, 'src', 'cli.lua');

// --- Helper Functions ---

// Provides a fallback message if obfuscation fails
const applyFallback = (rawCode) => {
    return `${FALLBACK_WATERMARK}\n${rawCode}`;
};

/**
 * Core function to execute the external Lua obfuscator CLI
 * Now accepts the preset dynamically.
 */
const runObfuscationStep = async (rawLuaCode, preset) => {
    const timestamp = Date.now();
    const tempFile = path.join(__dirname, `temp_${timestamp}.lua`);
    const outputFile = path.join(__dirname, `obf_${timestamp}.lua`);
    
    // 1. Write raw code to temporary input file
    try {
        fs.writeFileSync(tempFile, rawLuaCode, 'utf8');
    } catch (e) {
        console.error('File Write Error:', e);
        return { code: applyFallback(rawLuaCode), success: false, details: 'Server file system error during input write.' };
    }

    // 2. Execute obfuscator, using the dynamic preset
    const command = `lua ${SCRIPT_LUA_PATH} --preset ${preset} --out ${outputFile} ${tempFile}`;
    
    return new Promise((resolve) => {
        exec(command, { timeout: 15000 }, (error, stdout, stderr) => {
            // 3. Cleanup input file immediately
            try { fs.unlinkSync(tempFile); } catch (e) { /* silent fail */ } 
            
            if (error || stderr) {
                const executionDetails = error ? (error.killed ? 'Timeout (15s) or Process Kill.' : error.message) : stderr;
                console.error(`Prometheus Execution Failed: ${executionDetails}`);
                
                // 4. Cleanup output file if it exists, then fallback
                if (fs.existsSync(outputFile)) { try { fs.unlinkSync(outputFile); } catch (e) { /* silent fail */ } }
                
                resolve({ 
                    code: applyFallback(rawLuaCode), 
                    success: false,
                    details: executionDetails
                });
                return;
            }
            
            // 5. Success: Read output, apply watermark, cleanup output file
            let obfuscatedCode = '';
            try {
                obfuscatedCode = fs.readFileSync(outputFile, 'utf8');
                obfuscatedCode = WATERMARK + obfuscatedCode;
                fs.unlinkSync(outputFile);
            } catch (e) {
                 console.error('Obfuscator output file read/cleanup error:', e);
                 // Fallback if file ops fail after successful execution
                 resolve({ 
                     code: applyFallback(rawLuaCode), 
                     success: false,
                     details: 'Server file system error during output read.'
                 });
                 return;
            }
            
            resolve({ 
                code: obfuscatedCode, 
                success: true,
                details: 'Obfuscation successful.'
            });
        });
    });
};


// =======================================================
// === OBFUSCATE ROUTE (Only remaining endpoint) =========
// =======================================================
app.post('/api/obfuscate', async (req, res) => {
    const rawLuaCode = req.body.code;
    const preset = req.body.preset || 'Medium'; // Default to Medium if not provided
    
    if (!rawLuaCode || typeof rawLuaCode !== 'string') {
        return res.status(400).json({ error: 'A "code" field containing Lua script is required.' });
    }

    try {
        const result = await runObfuscationStep(rawLuaCode, preset);
        
        if (result.success) {
            res.status(200).json({ 
                obfuscatedCode: result.code,
                success: true,
                message: result.details
            });
        } else {
            // If obfuscation fails, return 422 Unprocessable Entity with details
            res.status(422).json({
                error: 'Obfuscation Failed',
                details: result.details,
                obfuscatedCode: result.code, // Send fallback code for display
                success: false
            });
        }
        
    } catch (error) {
        console.error('Obfuscate route execution error:', error.stack);
        const fallback = applyFallback(rawLuaCode || '');
        return res.status(500).json({ 
            error: 'Internal Server Error', 
            details: error.message,
            obfuscatedCode: fallback, 
            success: false 
        });
    }
});


// Basic Health Check / Root endpoint (Redirect to main UI)
app.get('/', (req, res) => {
    res.redirect('/index.html');
});


// Start the server
app.listen(port, () => {
    console.log(`Server listening on port ${port}. Only the /api/obfuscate route is active.`);
});
