// @ts-check
const { test, expect } = require('@playwright/test');
const { login } = require('../helpers/auth');

test.describe('Login & Dashboard Access', () => {
  test('Teacher login → dashboard + sidebar', async ({ page }) => {
    await login(page, 'teacher');

    await expect(page).toHaveURL(/index\.html/);
    await expect(page.locator('.sidebar')).toBeVisible();
    await expect(page.locator('.nav-item:has-text("대시보드")').first()).toBeVisible();
    await expect(page.locator('.nav-item:has-text("학생 관리")')).toBeVisible();
    await expect(page.locator('.nav-item:has-text("시험 관리")')).toBeVisible();
  });

  test('Director login → admin mode + sidebar', async ({ page }) => {
    await login(page, 'director');

    await expect(page).toHaveURL(/index\.html/);
    await expect(page.locator('.sidebar')).toBeVisible();
    await expect(page.locator('.nav-item:has-text("학원 현황")')).toBeVisible();
    await expect(page.locator('.nav-item:has-text("선생님 관리")')).toBeVisible();
  });

  test('Student login → student dashboard + sidebar', async ({ page }) => {
    await login(page, 'student');

    await expect(page).toHaveURL(/index\.html/);
    await expect(page.locator('.sidebar')).toBeVisible();
    await expect(page.locator('.nav-item:has-text("내 성적")')).toBeVisible();
    await expect(page.locator('.nav-item:has-text("시험 응시")')).toBeVisible();
  });
});
