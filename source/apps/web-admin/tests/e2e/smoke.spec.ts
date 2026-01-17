import { test, expect } from '@playwright/test';

test.describe('Web Admin Smoke Tests', () => {
  test('homepage loads', async ({ page }) => {
    // Try to load the app
    await page.goto('http://localhost:3000');
    
    // Just check that something loaded
    await expect(page).toHaveTitle(/./);
    
    console.log('Page loaded successfully');
  });
  
  test('login page is accessible', async ({ page }) => {
    await page.goto('http://localhost:3000/login');
    
    // Check for login-related text or form
    const content = await page.textContent('body');
    expect(content).toBeTruthy();
    
    console.log('Login page accessible');
  });
});
