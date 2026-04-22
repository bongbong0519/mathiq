import { createClient } from '@supabase/supabase-js';

// Supabase 에러 메시지 한국어 매핑
const ERROR_MESSAGES = {
  'A user with this email address has already been registered': '이미 등록된 이메일입니다. 다른 이메일을 사용해주세요.',
  'User already registered': '이미 등록된 이메일입니다. 다른 이메일을 사용해주세요.',
  'Email address is invalid': '유효하지 않은 이메일 형식입니다.',
  'Password should be at least 6 characters': '비밀번호는 최소 6자 이상이어야 합니다.',
  'Unable to validate email address: invalid format': '이메일 형식이 올바르지 않습니다.',
};

function translateError(message) {
  // 정확히 일치하는 메시지 찾기
  if (ERROR_MESSAGES[message]) return ERROR_MESSAGES[message];

  // 부분 일치 검색
  for (const [key, value] of Object.entries(ERROR_MESSAGES)) {
    if (message.includes(key)) return value;
  }

  // 매핑되지 않은 에러는 일반 메시지로
  return '계정 생성 중 오류가 발생했습니다. 다시 시도해주세요.';
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { email, password, name, school, grade, teacher_id } = req.body;

  if (!email || !password || !name || !teacher_id) {
    return res.status(400).json({ error: '필수 항목이 누락되었습니다' });
  }

  const supabaseAdmin = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
  );

  try {
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    });

    if (authError) throw new Error(authError.message);
    const userId = authData.user.id;

    await supabaseAdmin.from('profiles').insert({
      id: userId,
      role: 'student',
      name,
      school: school || null,
      status: 'approved',
      subscription_tier: 'campus',
      point_balance: 0
    });

    await supabaseAdmin.from('students').insert({
      id: userId,
      teacher_id,
      name,
      email,
      school: school || null,
      grade: grade || null,
    });

    return res.status(200).json({ success: true, userId });
  } catch (e) {
    const koreanError = translateError(e.message);
    return res.status(500).json({ error: koreanError });
  }
}
