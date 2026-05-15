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

  await page.goto('/index.html');
  await page.waitForLoadState('networkidle');

  // Open auth overlay
  await page.evaluate(() => {
    if (typeof openAuthFromLanding === 'function') {
      openAuthFromLanding('login');
    }
  });
  await page.waitForTimeout(500);

  // Fill login form
  await page.locator('#loginEmail').fill(creds.email);
  await page.locator('#loginPassword').fill(creds.password);

  // Submit
  await page.evaluate(() => {
    if (typeof handleLogin === 'function') {
      handleLogin();
    }
  });

  // Wait for dashboard
  await page.waitForSelector('.sidebar', { timeout: 15000 });
}

module.exports = { login, credentials };
