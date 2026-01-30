#!/usr/bin/env node
/**
 * Anti-XSS Gate: Detect unsafe innerHTML usage
 * 
 * Fails if it finds innerHTML assignments with template literals or concatenation
 * that could lead to XSS vulnerabilities.
 * 
 * Exit codes:
 *   0 - No unsafe innerHTML found
 *   2 - Unsafe innerHTML detected
 */

const fs = require('fs');
const path = require('path');

const TARGET_FILE = path.join(__dirname, '../../source/apps/web-admin/index.html');

console.log('[NO-UNSAFE-INNERHTML] Scanning for XSS vulnerabilities...');
console.log(`[NO-UNSAFE-INNERHTML] Target: ${TARGET_FILE}\n`);

if (!fs.existsSync(TARGET_FILE)) {
    console.error(`[NO-UNSAFE-INNERHTML] ❌ Target file not found: ${TARGET_FILE}`);
    process.exit(2);
}

const content = fs.readFileSync(TARGET_FILE, 'utf8');
const lines = content.split('\n');

let violations = [];

// Patterns that indicate unsafe innerHTML usage
const UNSAFE_PATTERNS = [
    // innerHTML with template literals containing ${...}
    { regex: /innerHTML\s*[+]?=\s*`[^`]*\$\{/g, desc: 'innerHTML with template literal interpolation' },
    // innerHTML concatenation with + operator
    { regex: /innerHTML\s*\+=\s*(?!''|""|``)(?!.*document\.createElement)/g, desc: 'innerHTML concatenation' },
    // innerHTML assigned from variables that might contain HTML
    { regex: /innerHTML\s*=\s*[^'"`]\w+/g, desc: 'innerHTML from variable' }
];

lines.forEach((line, index) => {
    const lineNum = index + 1;
    
    UNSAFE_PATTERNS.forEach(pattern => {
        if (pattern.regex.test(line)) {
            // Exclude known safe patterns
            const isSafeReset = /innerHTML\s*=\s*['"`]['"`]/.test(line); // innerHTML = ''
            const isSafeFixed = /innerHTML\s*=\s*['"`]<[^$]*>/.test(line); // innerHTML = '<fixed html>'
            const isDOMCreation = /createElement|textContent/.test(line); // Safe DOM manipulation
            
            if (!isSafeReset && !isSafeFixed && !isDOMCreation) {
                violations.push({
                    line: lineNum,
                    code: line.trim(),
                    pattern: pattern.desc
                });
            }
        }
        // Reset regex for next iteration
        pattern.regex.lastIndex = 0;
    });
});

if (violations.length === 0) {
    console.log('[NO-UNSAFE-INNERHTML] ✅ No unsafe innerHTML usage detected');
    console.log('[NO-UNSAFE-INNERHTML] All innerHTML operations are safe\n');
    process.exit(0);
} else {
    console.error('[NO-UNSAFE-INNERHTML] ❌ UNSAFE innerHTML DETECTED!\n');
    console.error(`Found ${violations.length} violation(s):\n`);
    
    violations.forEach(v => {
        console.error(`  Line ${v.line}: ${v.pattern}`);
        console.error(`    ${v.code}`);
        console.error('');
    });
    
    console.error('[NO-UNSAFE-INNERHTML] Fix required:');
    console.error('  - Replace innerHTML concatenation with DOM APIs');
    console.error('  - Use createElement() and textContent instead');
    console.error('  - Or escape HTML content before assignment\n');
    
    process.exit(2);
}
