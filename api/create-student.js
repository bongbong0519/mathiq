import { createClient } from '@supabase/supabase-js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { email, password, name, grade, class_name, teacher_id } = req.body;

  if (!email || !password || !name || !teacher_id) {
    return res.status(400).json({ error: '필수 항목이 누락되었습니다' });
  }

  // Service Role Key로 Admin 클라이언트 생성
  const supabaseAdmin = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
  );

  try {
    // 1. Auth에 학생 계정 생성
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    });

    if (authError) throw new Error(authError.message);

    const userId = authData.user.id;

    // 2. profiles 테이블에 학생 프로필 저장
    await supabaseAdmin.from('profiles').insert({
      id: userId,
      role: 'student',
      name,
      status: 'approved'
    });

    // 3. students 테이블에 저장
    await supabaseAdmin.from('students').insert({
      id: userId,
      teacher_id,
      name,
      grade: parseInt(grade) || null,
      class_name: class_name || null
    });

    return res.status(200).json({ success: true, userId });

  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
