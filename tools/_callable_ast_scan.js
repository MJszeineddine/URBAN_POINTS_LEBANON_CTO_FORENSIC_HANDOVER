#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const ts = require('typescript');

const srcDir = process.argv[2] || './src';

if (!fs.existsSync(srcDir)) {
  console.error(`Error: source directory not found: ${srcDir}`);
  process.exit(1);
}

const callables = new Set();

function walkDir(dir) {
  const files = fs.readdirSync(dir, { withFileTypes: true });
  for (const file of files) {
    const fullPath = path.join(dir, file.name);
    if (file.isDirectory()) {
      walkDir(fullPath);
    } else if (file.isFile() && file.name.endsWith('.ts')) {
      scanFile(fullPath);
    }
  }
}

function scanFile(filePath) {
  try {
    const source = fs.readFileSync(filePath, 'utf-8');
    const sourceFile = ts.createSourceFile(
      filePath,
      source,
      ts.ScriptTarget.Latest,
      true,
      ts.ScriptKind.TS
    );
    
    visit(sourceFile);
  } catch (err) {
    console.error(`Warning: failed to parse ${filePath}: ${err.message}`);
  }
}

function visit(node) {
  if (ts.isVariableStatement(node)) {
    if (node.modifiers && node.modifiers.some(m => m.kind === ts.SyntaxKind.ExportKeyword)) {
      for (const decl of node.declarationList.declarations) {
        const name = decl.name.text;
        if (decl.initializer) {
          const text = decl.initializer.getText();
          if (
            text.includes('onCall(') ||
            text.includes('https.onCall(') ||
            text.includes('functions.https.onCall(') ||
            text.includes('functions.v2.https.onCall(')
          ) {
            callables.add(name);
          }
        }
      }
    }
  }
  
  if (ts.isExportDeclaration(node)) {
    if (node.exportClause && ts.isNamedExports(node.exportClause)) {
      for (const elem of node.exportClause.elements) {
        const name = elem.propertyName ? elem.propertyName.text : elem.name.text;
        callables.add(name);
      }
    }
  }
  
  ts.forEachChild(node, visit);
}

walkDir(srcDir);

console.log(JSON.stringify({
  callables: Array.from(callables).sort(),
  scan_mode: 'ts-ast',
  timestamp: new Date().toISOString()
}));
