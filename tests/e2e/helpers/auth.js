// @ts-check
require('dotenv').config();

const credentials = {
  teacher: {
    email: process.env.E2E_TEACHER_EMAIL,
    password: process.env.E2E_TEACHER_PASSWORD,
  },
  director: {
    email: process.env.E2E_DIRECTOR_EMAIL,
    password: process.env.E2E_DIRECTOR_PASSWORD,
  },
  student: {
    email: process.env.E2E_STUDENT_EMAIL,
    password: process.env.E2E_STUDENT_PASSWORD,
  },
};

async function login(page, persona) {
  const creds = credentials[persona];
  if (!creds || !creds.email || !creds.password) {
    throw new Error(`Missing credentials for persona: ${persona}. Check .env file.`);
  }

  await page.goto('/landing.html');
  await page.click('text=로그인');
  await page.waitForSelector('input[type="email"]', { timeout: 5000 });
  await page.fill('input[type="email"]', creds.email);
  await page.fill('input[type="password"]', creds.password);
  await page.click('button:has-text("로그인")');
  await page.waitForURL(/index\.html/, { timeout: 10000 });
}

module.exports = { login, credentials };
