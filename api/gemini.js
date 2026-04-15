// Vercel body parser 설정 — base64 이미지가 포함된 요청 처리
export const config = {
  api: {
    bodyParser: {
      sizeLimit: '50mb',
    },
  },
};

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'GEMINI_API_KEY가 Vercel 환경 변수에 설정되지 않았습니다.' });
  }

  // body에서 model 추출 후 제거 (URL에만 사용, body에 포함 시 Gemini API 오류)
  const { model: modelFromBody, ...geminiBody } = req.body || {};
  const model = modelFromBody || 'gemini-2.0-flash';

  let googleRes;
  try {
    googleRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(geminiBody),
      }
    );
  } catch (networkErr) {
    return res.status(502).json({ error: `Google API 네트워크 오류: ${networkErr.message}` });
  }

  // Google API 응답을 그대로 전달 (오류 포함)
  let data;
  try {
    data = await googleRes.json();
  } catch {
    return res.status(502).json({ error: `Google API 응답 파싱 실패 (status: ${googleRes.status})` });
  }

  return res.status(googleRes.status).json(data);
}
