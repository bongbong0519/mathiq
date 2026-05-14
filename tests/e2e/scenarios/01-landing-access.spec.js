// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Landing Page', () => {
  test('6 main nodes are displayed', async ({ page }) => {
    const consoleErrors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('/landing.html');

    // Wait for page to fully load
    await page.waitForLoadState('networkidle');

    // Check page title or main element exists
    await expect(page.locator('body')).toBeVisible();

    // 6 main nodes (박제 2026-05-05): 학습 / 학생관리 / 강사도구 / 커뮤니티 / 운영 / 정보
    const nodeLabels = ['학습', '학생관리', '강사도구', '커뮤니티', '운영', '정보'];

    for (const label of nodeLabels) {
      const node = page.locator(`text=${label}`).first();
      await expect(node).toBeVisible({ timeout: 10000 });
    }

    // Console errors should be 0
    expect(consoleErrors).toHaveLength(0);
  });
});
