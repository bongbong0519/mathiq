// /api/generate-solution.js
// AI 해설 작성 또는 기존 해설 수정
//
// 요청:  POST /api/generate-solution { question_text, choices, original_solution?, modify_instruction? }
// 응답:  { solution_latex, final_answer, confidence }

export const config = {
  maxDuration: 60,
};

function buildSystemPrompt(hasOriginal, hasInstruction) {
  const baseRules = `[LaTeX 표기 규칙]
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
- 벡터: \\vec{v}
- 각도: 90^{\\circ}
- 조합/순열: _{n}C_{r}, _{n}P_{r}, _{n}H_{r}

[출력 형식 - 순수 JSON만]
{
  "solution_latex": "풀이 LaTeX (단계별로 \\n 줄바꿈)",
  "final_answer": "최종 답 (예: ①, 3, 15)",
  "confidence": "high" | "medium" | "low"
}`;

  if (hasOriginal && hasInstruction) {
    // 기존 해설 수정 모드
    return `당신은 한국 고등학교 수학 해설을 수정하는 전문가입니다.

[작업]
기존 해설을 사용자의 요청에 따라 수정하세요.
- 수정 요청 부분만 반영하고 나머지는 유지
- LaTeX 문법 오류가 있으면 함께 수정
- 답이 바뀌지 않도록 주의 (계산 실수 수정 요청 시에는 예외)

${baseRules}

응답은 반드시 { 로 시작하고 } 로 끝나는 순수 JSON.`;
  }

  // 새 해설 작성 모드
  return `당신은 한국 고등학교 수학 문제 해설을 작성하는 전문가입니다.

[작업]
주어진 수학 문제에 대해 완전한 풀이를 작성하세요.

[해설 작성 규칙]
1. 한국 고등학교 수학 수준에 맞게 작성
2. 풀이를 3~8단계로 나누어 설명
3. 핵심 공식이나 정리 사용 시 명시
4. 계산 과정을 생략하지 말 것
5. 학생이 이해하기 쉽게 자연스러운 문장으로
6. 마지막에 최종 답 명시

${baseRules}

[주의]
- 선택지가 있으면 보기 중에서 답 선택
- 주관식이면 계산 결과 제시
- 답을 추측하지 말고, 정확히 풀어서 도출
- 확신이 없으면 confidence: "low"

응답은 반드시 { 로 시작하고 } 로 끝나는 순수 JSON.`;
}

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
    const {
      question_text,
      choices = [],
      original_solution = null,
      modify_instruction = null,
    } = req.body || {};

    if (!question_text) {
      return res.status(400).json({ error: 'question_text가 필요합니다.' });
    }

    const hasOriginal = original_solution && original_solution.trim().length > 0;
    const hasInstruction = modify_instruction && modify_instruction.trim().length > 0;

    const systemPrompt = buildSystemPrompt(hasOriginal, hasInstruction);

    // 사용자 메시지 구성
    let userMessage = '';

    if (hasOriginal && hasInstruction) {
      // 수정 모드
      userMessage = `[문제]
${question_text}

${choices.length > 0 ? `[선택지]\n${choices.join('\n')}\n` : ''}
[기존 해설]
${original_solution}

[수정 요청]
${modify_instruction}

위 요청에 따라 해설을 수정해주세요.`;
    } else {
      // 새 해설 작성 모드
      userMessage = `[문제]
${question_text}

${choices.length > 0 ? `[선택지]\n${choices.join('\n')}\n` : ''}
이 문제의 완전한 풀이를 작성해주세요.`;
    }

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
        system: systemPrompt,
        messages: [
          {
            role: 'user',
            content: userMessage,
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
      final_answer: result.final_answer || '',
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
