const express = require('express');
const path = require('path');
const { solidityToHaskell } = require('./index');
const parser = require('@solidity-parser/parser');
const { execSync } = require('child_process');
const fs = require('fs');
const os = require('os');

const app = express();
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

// Validate Solidity code
app.post('/validate-solidity', (req, res) => {
    try {
        parser.parse(req.body.code);
        res.json({ valid: true });
    } catch (error) {
        res.json({ valid: false, error: error.message });
    }
});

// Validate Haskell code
app.post('/validate-haskell', (req, res) => {
    try {
        const tempFile = path.join(os.tmpdir(), `temp_${Date.now()}.hs`);
        fs.writeFileSync(tempFile, req.body.code);
        
        try {
            execSync(`ghc -fno-code ${tempFile} 2>&1`);
            res.json({ valid: true });
        } catch (error) {
            res.json({ valid: false, error: error.message });
        } finally {
            fs.unlinkSync(tempFile);
        }
    } catch (error) {
        res.json({ valid: false, error: error.message });
    }
});

app.post('/convert', async (req, res) => {
    try {
        const { solidity } = req.body;
        const haskell = solidityToHaskell(solidity);
        res.json({ haskell });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

const PORT = 3000;
app.listen(PORT, () => console.log(`Server running at http://localhost:${PORT}`));