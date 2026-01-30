#!/usr/bin/env python3
"""
Test XSS detector against synthetic dangerous samples.
All samples must be flagged as dangerous.
"""
import re

def check_xss_vulnerable(line):
    """
    Detect XSS vulnerabilities while avoiding false positives for safe clears.
    """
    # Always flag dangerouslySetInnerHTML and document.write
    if re.search(r'dangerouslySetInnerHTML|document\.write', line, re.IGNORECASE):
        return True
    
    # Check for safe clears - these should NOT be flagged
    if re.search(r'\.innerHTML\s*=\s*[\'"`][\'\"`]', line):  # .innerHTML = '' or "" or ``
        return False
    if re.search(r'\.innerHTML\s*=\s*null', line):  # .innerHTML = null
        return False
    
    # Flag dangerous innerHTML assignments:
    # .innerHTML += (always dangerous)
    if re.search(r'\.innerHTML\s*\+=', line):
        return True
    
    # .innerHTML = non-literal (variable, function call, template, concatenation, etc.)
    if re.search(r'\.innerHTML\s*=(?!\s*[\'"`][\'\"`])(?!\s*null)', line):
        # Check if there's actual content after the =
        match = re.search(r'\.innerHTML\s*=\s*(.+?)(?:;|$)', line)
        if match:
            content = match.group(1).strip()
            # If content is not empty and not just a safe clear, flag it
            if content and content not in ("''", '""', '``', 'null'):
                return True
    
    return False

# DANGEROUS SYNTHETIC SAMPLES - ALL MUST BE FLAGGED
SYNTHETIC_SAMPLES = [
    'tbody.innerHTML += row;',
    'container.innerHTML += `<tr><td>${offer.title}</td></tr>`;',
    'el.innerHTML = userHtml;',
    'div.innerHTML = getData();',
    'span.innerHTML = `<p>${untrusted}</p>`;',
    'table.innerHTML = "<tr>" + cells;',
    'elem.innerHTML = htmlFromServer;',
    'dangerouslySetInnerHTML={{__html: user}};',
    'document.write(content);',
    'document.write("<h1>" + title);',
]

print('[SYNTHETIC] XSS Detector - Synthetic Sample Test')
print('=' * 70)
print('Testing all samples must be flagged as dangerous...\n')

passed = 0
failed = 0

for sample in SYNTHETIC_SAMPLES:
    result = check_xss_vulnerable(sample)
    status = 'PASS' if result else 'FAIL'
    symbol = '✓' if result else '✗'
    
    if result:
        passed += 1
    else:
        failed += 1
    
    print(f'{symbol} {status}: {sample[:65]}{"..." if len(sample) > 65 else ""}')
    if not result:
        print(f'  ERROR: Expected flagged but got: {result}')

print()
print('=' * 70)
print(f'Results: {passed} passed, {failed} failed out of {len(SYNTHETIC_SAMPLES)} samples')

if failed == 0:
    print('✅ All dangerous samples correctly flagged!')
    exit(0)
else:
    print(f'❌ {failed} sample(s) NOT flagged (false negatives detected)!')
    exit(1)
