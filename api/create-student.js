const { createClient } = require('@supabase/supabase-js');

module.exports = async function handler(req, res) {
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
      status: 'approved'
    });

    await supabaseAdmin.from('students').insert({
      teacher_id,
      name,
      grade: grade || null,
      class_name: school || null
    });

    return res.status(200).json({ success: true, userId });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
};
