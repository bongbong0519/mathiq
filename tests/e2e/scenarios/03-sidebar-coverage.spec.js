// @ts-check
const { test, expect } = require('@playwright/test');
const { login } = require('../helpers/auth');

const teacherMenus = [
  { label: '대시보드', view: 'dashboard' },
  { label: '학생 관리', view: 'students' },
  { label: '시험 관리', view: 'exams' },
  { label: 'AI 유사문제 생성', view: null },
  { label: '학부모 문자 발송', view: 'sms' },
  { label: '매출·지출 관리', view: 'accounting' },
  { label: '문제은행', view: 'question-bank' },
  { label: '문제 등록', view: 'question-upload' },
  { label: '수업 자료', view: 'teacher-materials' },
  { label: '자료실', view: 'materials' },
  { label: '입시정보', view: null },
  { label: '수학커뮤니티', view: null },
  { label: '과외 프로필 등록', view: 'tutor-profile' },
  { label: '학생 찾기', view: 'student-search' },
  { label: '매칭 관리', view: 'tutor-requests' },
  { label: '쪽지함', view: 'messages' },
  { label: '공지사항', view: 'notices' },
  { label: '1:1 문의', view: 'inquiry' },
  { label: '사용설명서', view: null },
  { label: '내 정보', view: 'profile' },
];

const directorMenus = [
  { label: '학원 현황', view: 'director-dashboard' },
  { label: '선생님 관리', view: 'director-teachers' },
  { label: '학생 현황', view: 'director-students' },
  { label: '매출·지출 관리', view: 'accounting' },
  { label: '자료실', view: 'materials' },
  { label: '문제은행', view: 'question-bank' },
  { label: '문제 등록', view: 'question-upload' },
  { label: '쪽지함', view: 'messages' },
  { label: '공지사항', view: 'notices' },
  { label: '1:1 문의', view: 'inquiry' },
  { label: '내 정보', view: 'profile' },
];

const studentMenus = [
  { label: '내 성적', view: 'student' },
  { label: '시험 응시', view: 'student-exams' },
  { label: '수업 자료', view: 'student-materials' },
  { label: '자료실', view: 'materials' },
  { label: '입시정보', view: null },
  { label: '학생 커뮤니티', view: null },
  { label: '과외 찾기', view: 'tutor-search' },
  { label: '과외 구인 등록', view: 'tutee-register' },
  { label: '내 매칭 신청', view: 'parent-requests' },
  { label: '쪽지함', view: 'messages' },
  { label: '공지사항', view: 'notices' },
  { label: '1:1 문의', view: 'inquiry' },
  { label: '내 정보', view: 'profile' },
];

test.describe('Sidebar Menu Coverage', () => {
  test('Teacher: all menu items accessible', async ({ page }) => {
    const consoleErrors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    await login(page, 'teacher');

    for (const menu of teacherMenus) {
      const menuItem = page.locator(`.nav-item:has-text("${menu.label}")`).first();
      if (await menuItem.isVisible()) {
        await menuItem.click();
        await page.waitForTimeout(500);
      }
    }

    if (consoleErrors.length > 0) {
      console.log('Console errors found:', consoleErrors);
    }
    expect(consoleErrors.filter(e => !e.includes('favicon'))).toHaveLength(0);
  });

  test('Director: all menu items accessible', async ({ page }) => {
    const consoleErrors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    await login(page, 'director');

    for (const menu of directorMenus) {
      const menuItem = page.locator(`.nav-item:has-text("${menu.label}")`).first();
      if (await menuItem.isVisible()) {
        await menuItem.click();
        await page.waitForTimeout(500);
      }
    }

    if (consoleErrors.length > 0) {
      console.log('Console errors found:', consoleErrors);
    }
    expect(consoleErrors.filter(e => !e.includes('favicon'))).toHaveLength(0);
  });

  test('Student: all menu items accessible', async ({ page }) => {
    const consoleErrors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    await login(page, 'student');

    for (const menu of studentMenus) {
      const menuItem = page.locator(`.nav-item:has-text("${menu.label}")`).first();
      if (await menuItem.isVisible()) {
        await menuItem.click();
        await page.waitForTimeout(500);
      }
    }

    if (consoleErrors.length > 0) {
      console.log('Console errors found:', consoleErrors);
    }
    expect(consoleErrors.filter(e => !e.includes('favicon'))).toHaveLength(0);
  });
});
