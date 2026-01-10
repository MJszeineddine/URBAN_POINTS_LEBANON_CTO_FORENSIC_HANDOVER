# Urban Points Lebanon - Design System

**Version**: 1.0  
**Date**: January 3, 2025  
**Status**: Foundation Definition

---

## COLOR PALETTE

### Primary Colors
```
Primary:      #3498db  (Brand Blue)
Primary Dark: #2980b9  (Hover/Active State)
Primary Light:#5dade2  (Disabled/Subtle)
```

### Secondary Colors
```
Secondary:      #2c3e50  (Dark Gray - Headers, Text)
Secondary Dark: #1a252f  (Deep backgrounds)
Secondary Light:#4a5f7f  (Subtle text)
```

### Accent Colors
```
Success: #27ae60  (Green - Approvals, Positive Actions)
Warning: #f39c12  (Orange - Alerts, Attention)
Error:   #e74c3c  (Red - Errors, Rejections, Deletions)
Info:    #3498db  (Blue - Information, Tips)
```

### Neutral Colors
```
Background:    #f5f5f5  (Page Background)
Surface:       #ffffff  (Cards, Modals)
Border:        #ddd     (Dividers, Inputs)
Text Primary:  #2c3e50  (Main Text)
Text Secondary:#7f8c8d  (Labels, Captions)
Text Disabled: #95a5a6  (Disabled Text)
```

### Points/Loyalty Colors
```
Points Gold:   #f39c12  (Points Display)
QR Scan:       #9b59b6  (QR Code Related)
Redemption:    #e74c3c  (Redemption Actions)
```

---

## TYPOGRAPHY

### Font Families
```
Primary:   -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif
Monospace: 'Fira Code', 'Courier New', monospace (code, QR tokens)
```

### Font Sizes
```
H1: 32px / 2rem     (weight: 700) - Page Titles
H2: 24px / 1.5rem   (weight: 600) - Section Headers
H3: 20px / 1.25rem  (weight: 600) - Card Titles
H4: 18px / 1.125rem (weight: 600) - Subsection Headers
H5: 16px / 1rem     (weight: 600) - List Headers
H6: 14px / 0.875rem (weight: 600) - Small Headers

Body:    16px / 1rem     (weight: 400) - Body Text
Small:   14px / 0.875rem (weight: 400) - Captions, Labels
Tiny:    12px / 0.75rem  (weight: 500) - Badges, Tags
```

### Line Heights
```
Tight:   1.2  (Headers)
Normal:  1.5  (Body Text)
Relaxed: 1.75 (Long-form content)
```

---

## SPACING SYSTEM

### Scale (8px base)
```
xs:  4px  / 0.25rem  - Tight spacing, badge padding
sm:  8px  / 0.5rem   - Button padding, icon margins
md:  16px / 1rem     - Card padding, form fields
lg:  24px / 1.5rem   - Section spacing
xl:  32px / 2rem     - Page margins
2xl: 48px / 3rem     - Large section gaps
3xl: 64px / 4rem     - Hero sections
```

### Component Spacing
```
Button Padding:     12px 24px  (vertical horizontal)
Input Padding:      12px       (all sides)
Card Padding:       20px       (all sides)
Modal Padding:      30px       (all sides)
Page Container:     30px       (all sides)
Section Margin:     30px       (bottom)
```

---

## BUTTONS

### Primary Button
```css
background: #3498db
color: #ffffff
padding: 12px 24px
border-radius: 4px
font-size: 16px
font-weight: 500
transition: background 0.3s

:hover → background: #2980b9
:disabled → background: #95a5a6, cursor: not-allowed
```

### Secondary Button
```css
background: transparent
color: #3498db
border: 2px solid #3498db
padding: 10px 22px
border-radius: 4px

:hover → background: #3498db, color: #ffffff
```

### Danger Button
```css
background: #e74c3c
color: #ffffff
padding: 12px 24px

:hover → background: #c0392b
```

### Success Button
```css
background: #27ae60
color: #ffffff
padding: 12px 24px

:hover → background: #229954
```

### Small Button
```css
padding: 6px 12px
font-size: 13px
```

---

## INPUT FIELDS

### Text Input
```css
width: 100%
padding: 12px
border: 1px solid #ddd
border-radius: 4px
font-size: 14px

:focus → border-color: #3498db, outline: none
:error → border-color: #e74c3c
:disabled → background: #f8f9fa, cursor: not-allowed
```

### Label
```css
display: block
margin-bottom: 5px
font-weight: 500
font-size: 14px
color: #2c3e50
```

### Error Message
```css
color: #e74c3c
font-size: 12px
margin-top: 5px
```

---

## CARDS

### Standard Card
```css
background: #ffffff
padding: 20px
border-radius: 8px
box-shadow: 0 2px 5px rgba(0,0,0,0.1)
margin-bottom: 20px
```

### Stat Card
```css
background: #ffffff
padding: 20px
border-radius: 8px
box-shadow: 0 2px 5px rgba(0,0,0,0.1)

.title → font-size: 14px, color: #7f8c8d, text-transform: uppercase
.value → font-size: 32px, font-weight: bold, color: #2c3e50
```

### Offer Card (Mobile)
```css
background: #ffffff
border-radius: 12px
box-shadow: 0 2px 8px rgba(0,0,0,0.1)
overflow: hidden

.image → aspect-ratio: 16:9
.content → padding: 16px
.title → font-size: 18px, font-weight: 600
.points → color: #f39c12, font-weight: bold
```

---

## BADGES

### Status Badges
```css
padding: 4px 8px
border-radius: 4px
font-size: 12px
font-weight: 500
display: inline-block
```

**Variants:**
```
.pending     → background: #fff3cd, color: #856404
.approved    → background: #d4edda, color: #155724
.rejected    → background: #f8d7da, color: #721c24
.compliant   → background: #d4edda, color: #155724
.non-compliant → background: #f8d7da, color: #721c24
```

---

## TABLES

### Table Structure
```css
table → width: 100%, border-collapse: collapse

thead → background: #f8f9fa

th, td → padding: 12px, text-align: left, border-bottom: 1px solid #ddd

th → font-weight: 600, color: #2c3e50, font-size: 14px

td → font-size: 14px, color: #333
```

---

## MODAL/DIALOG

### Modal Overlay
```css
position: fixed
top: 0, left: 0
width: 100%, height: 100%
background: rgba(0,0,0,0.5)
z-index: 1000
display: flex
justify-content: center
align-items: center
```

### Modal Content
```css
background: #ffffff
padding: 30px
border-radius: 8px
width: 90%
max-width: 500px
box-shadow: 0 4px 20px rgba(0,0,0,0.3)
```

---

## NAVIGATION

### Navbar
```css
background: #2c3e50
color: #ffffff
padding: 15px 30px
display: flex
justify-content: space-between
align-items: center
```

### Tabs
```css
background: #ffffff
padding: 0 30px
border-bottom: 1px solid #ddd
display: flex
gap: 10px

.tab → 
  padding: 15px 20px
  cursor: pointer
  border-bottom: 3px solid transparent
  transition: all 0.3s
  font-weight: 500
  
  :hover → background: #f8f9fa
  .active → border-bottom-color: #3498db, color: #3498db
```

---

## ICONOGRAPHY

### Icon Sizes
```
Small:  16px (inline text icons)
Medium: 24px (buttons, list items)
Large:  48px (empty states)
XLarge: 64px (hero sections)
```

### Icon Colors
```
Primary:   #3498db
Secondary: #7f8c8d
Success:   #27ae60
Warning:   #f39c12
Error:     #e74c3c
```

---

## BORDER RADIUS

### Scales
```
None:   0px     - Tables, strict layouts
Small:  4px     - Buttons, inputs, badges
Medium: 8px     - Cards, modals
Large:  12px    - Mobile offer cards
Circle: 50%     - Avatars, icon buttons
```

---

## SHADOWS

### Elevation Levels
```
Level 1: 0 2px 5px rgba(0,0,0,0.1)   - Cards, inputs
Level 2: 0 4px 10px rgba(0,0,0,0.15) - Dropdowns, tooltips
Level 3: 0 8px 20px rgba(0,0,0,0.2)  - Modals, elevated cards
Level 4: 0 12px 30px rgba(0,0,0,0.25) - Floating elements
```

---

## RESPONSIVE BREAKPOINTS

```
Mobile:   < 768px   (single column, full-width)
Tablet:   768-1024px (2 columns)
Desktop:  > 1024px   (3+ columns, max-width: 1200px)
```

### Grid System
```
Mobile:   1 column
Tablet:   2 columns, gap: 20px
Desktop:  3-4 columns, gap: 24px
```

---

## ANIMATION PRINCIPLES

### Transitions
```
Fast:   0.15s - Button hover, link hover
Normal: 0.3s  - Background color, border color
Slow:   0.5s  - Page transitions, modal open/close
```

### Easing
```
Standard: ease-in-out (default)
Entrance: ease-out (elements appearing)
Exit:     ease-in (elements disappearing)
```

---

## ACCESSIBILITY

### Minimum Requirements
```
Color Contrast: 4.5:1 (body text), 3:1 (large text)
Touch Targets: 44x44px minimum (mobile)
Focus States: Visible outline (2px solid #3498db)
Alt Text: Required for all images
Labels: Required for all form inputs
```

---

## COMPONENT CHECKLIST

- [x] Colors defined
- [x] Typography defined
- [x] Spacing scale defined
- [x] Buttons defined (4 variants)
- [x] Input fields defined
- [x] Cards defined (3 types)
- [x] Badges defined (5 status types)
- [x] Tables defined
- [x] Modals defined
- [x] Navigation defined
- [x] Icons defined
- [x] Border radius defined
- [x] Shadows defined
- [x] Responsive breakpoints defined
- [x] Animations defined
- [x] Accessibility guidelines defined

---

## USAGE NOTES

**Consistency**: All components must use colors, spacing, and typography from this system.

**Customization**: Variants are allowed but must maintain visual hierarchy and accessibility.

**Updates**: Design system changes require approval and documentation update.

**Implementation**: Reference this document when building UI components in:
- Mobile apps (Flutter)
- Web Admin (HTML/CSS)
- Future web customer portal

---

**Status**: ✅ FOUNDATION COMPLETE  
**Next Steps**: Create visual component library in Figma (optional)
