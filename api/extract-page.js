// /api/extract-page.js
// MathIQ 페이지 검수 - Claude Opus 4.7 Vision으로 수학 문제 추출
//
// 배포: Vercel Serverless Function (자동 배포)
// 환경변수 필요: ANTHROPIC_API_KEY (Vercel 프로젝트 설정에서 추가)
//
// 요청:  POST /api/extract-page { imageBase64, mediaType }
// 응답:  { problems: [...], raw: string }

export const config = {
  maxDuration: 60, // Vercel Hobby는 60초까지 허용 (기본 10초)
};

const SYSTEM_PROMPT = `당신은 한국 고등학교 수학 기출문제를 추출하는 전문가입니다.
이미지에서 모든 수학 문제를 정확하게 읽고 JSON 배열로 반환하세요.

[LaTeX 표기 규칙]
- 인라인 수식: $...$
- 디스플레이 수식: $$...$$
- 분수: \\dfrac{분자}{분모}
- 지수: x^{2}
- 아래첨자: x_{1}
- 중복조합 ₃H₁ → _{3}H_{1}
- 순열 ₃P₁ → _{3}P_{1}
- 조합 ₃C₁ → _{3}C_{1}
- 극한: \\lim_{x \\to 1}
- 시그마: \\sum_{k=1}^{n}
- 적분: \\int_{0}^{1}
- 선분 OC: \\overline{OC}
- 각도: 90^{\\circ}
- 루트: \\sqrt{7}

[응답 형식 - 순수 JSON만, 설명·코드블록 금지]
[
  {
    "q_num": "13",
    "question_text": "문제 본문 LaTeX (지문 + 식)",
    "has_figure": true,
    "figure_description": "그림이 있으면 상세 설명 (좌표, 도형, 라벨 모두), 없으면 null",
    "choices": ["① $-2$", "② $-1$", "③ $0$", "④ $1$", "⑤ $2$"],
    "points": "3",
    "subject_type": "객관식",
    "confidence": "high"
  }
]

[필수 규칙]
1. 문제 번호는 숫자만 (예: "13")
2. 한 페이지에 여러 문제가 있으면 모두 배열로
3. 객관식이 아니면 choices는 빈 배열 []
4. 배점 [2점] [3점] [4점] 읽어서 points에
5. 주관식/서답형이면 subject_type 구분
6. 확실하지 않은 기호는 [불명확] 표기하고 confidence: "low"
7. 그림 설명은 수학적 정보(좌표, 길이, 각도, 라벨) 모두 포함
8. 의미 없는 단어 나열, ㄱㄴㄷ 반복은 금지
9. 수학 기호 20% 미만이거나 그럴싸한 헛소리 우려 시 confidence: "low"

응답은 반드시 [ 로 시작하고 ] 로 끝나는 순수 JSON 배열.`;

export default async function handler(req, res) {
  // CORS (같은 도메인이면 불필요하지만 안전장치)
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

    // data:image/png;base64,... 프리픽스 제거
    const cleanBase64 = imageBase64.replace(/^data:image\/\w+;base64,/, '');

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-opus-4-5', // 2026-04-20 기준 최신 프로덕션 모델, 필요시 claude-opus-4-7로 교체
        max_tokens: 8000,
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
                text: '이 페이지의 모든 수학 문제를 추출하여 JSON 배열로 반환하세요.',
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

    // JSON 파싱 (코드블록이나 설명 섞여있을 경우 방어)
    let problems = [];
    try {
      // 순수 JSON으로 시작하는 경우
      problems = JSON.parse(rawText);
    } catch (e1) {
      // ```json ... ``` 감싸져 있는 경우
      const jsonMatch = rawText.match(/\[[\s\S]*\]/);
      if (jsonMatch) {
        try {
          problems = JSON.parse(jsonMatch[0]);
        } catch (e2) {
          return res.status(500).json({
            error: 'JSON 파싱 실패',
            raw: rawText,
          });
        }
      } else {
        return res.status(500).json({
          error: 'JSON 배열을 찾을 수 없음',
          raw: rawText,
        });
      }
    }

    return res.status(200).json({
      problems,
      raw: rawText,
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
