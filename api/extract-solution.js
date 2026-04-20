// /api/extract-solution.js
// 원본 해설 이미지 → LaTeX 변환
//
// 요청:  POST /api/extract-solution { imageBase64, mediaType }
// 응답:  { solution_latex, extracted_answer, confidence }

export const config = {
  maxDuration: 60,
};

const SYSTEM_PROMPT = `당신은 한국 고등학교 수학 해설을 LaTeX로 변환하는 전문가입니다.

[작업]
주어진 해설 이미지를 읽고, 풀이 과정을 깔끔한 LaTeX로 정리하세요.

[LaTeX 표기 규칙]
- 인라인 수식: $...$
- 디스플레이 수식: $$...$$
- 분수: \\dfrac{분자}{분모}
- 지수: x^{2}
- 아래첨자: x_{1}
- 극한: \\lim_{x \\to a}
- 시그마: \\sum_{k=1}^{n}
- 적분: \\int_{a}^{b}
- 루트: \\sqrt{x}
- 선분: \\overline{AB}
- 벡터: \\vec{v} 또는 \\overrightarrow{AB}
- 각도: 90^{\\circ}
- 조합/순열: _{n}C_{r}, _{n}P_{r}, _{n}H_{r}

[출력 형식 - 순수 JSON만]
{
  "solution_latex": "풀이 LaTeX (단계별로 줄바꿈, \\n 사용)",
  "extracted_answer": "최종 답 (예: ①, 3, 15 등)",
  "confidence": "high" | "medium" | "low"
}

[규칙]
1. 풀이를 단계별로 나누어 작성 (Step 1, Step 2 등 사용 금지 - 자연스러운 문장으로)
2. 핵심 공식이나 정리는 명시
3. 계산 과정 생략하지 말 것
4. 마지막에 최종 답 명시
5. 이미지가 불선명하거나 읽기 어려우면 confidence: "low"
6. 답을 확신할 수 없으면 extracted_answer에 "불명확" 기재

응답은 반드시 { 로 시작하고 } 로 끝나는 순수 JSON.`;

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'ANTHROPIC_API_KEY 환경변수가 설정되지 않았습니다.' });
  }

  try {
    const { imageBase64, mediaType = 'image/png' } = req.body || {};

    if (!imageBase64) {
      return res.status(400).json({ error: 'imageBase64가 필요합니다.' });
    }

    const cleanBase64 = imageBase64.replace(/^data:image\/\w+;base64,/, '');

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-opus-4-5',
        max_tokens: 4000,
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: mediaType,
                  data: cleanBase64,
                },
              },
              {
                type: 'text',
                text: '이 해설 이미지를 LaTeX로 변환해주세요.',
              },
            ],
          },
        ],
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error('Claude API error:', errText);
      return res.status(response.status).json({
        error: 'Claude API 호출 실패',
        detail: errText,
      });
    }

    const data = await response.json();
    const rawText = (data.content || [])
      .filter((c) => c.type === 'text')
      .map((c) => c.text)
      .join('\n')
      .trim();

    // JSON 파싱
    let result;
    try {
      result = JSON.parse(rawText);
    } catch (e1) {
      const jsonMatch = rawText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        try {
          result = JSON.parse(jsonMatch[0]);
        } catch (e2) {
          return res.status(500).json({
            error: 'JSON 파싱 실패',
            raw: rawText,
          });
        }
      } else {
        return res.status(500).json({
          error: 'JSON 객체를 찾을 수 없음',
          raw: rawText,
        });
      }
    }

    return res.status(200).json({
      solution_latex: result.solution_latex || '',
      extracted_answer: result.extracted_answer || '',
      confidence: result.confidence || 'medium',
      usage: data.usage,
    });
  } catch (err) {
    console.error('Handler error:', err);
    return res.status(500).json({
      error: '서버 내부 오류',
      detail: err.message,
    });
  }
}
