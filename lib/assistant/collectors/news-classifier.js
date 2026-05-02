// AI 분류·태깅 모듈
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

export async function classifyNews(news) {
  const prompt = `다음 뉴스를 분석해서 JSON으로 분류하세요.

뉴스 제목: ${news.title}
설명: ${news.description}
검색 키워드: ${news.keyword}

분류 규칙:
- source: ['교육부', '평가원', '시도교육청', '대학', '특목고', '뉴스기관'] 중 하나
- source_detail: 검색 키워드 그대로 (예: '서울대 입시', '광주광역시교육청')
- category: ['정책', '모의고사', '수능', '입시', '특목고', '대학', '의대', '지역'] 중 가장 적합한 1개
- summary: 봉쌤(현역 수학 교사+학원 부원장+MathIQ 운영자) 관점 2~3줄 요약
- tags: 핵심 키워드 3~5개 배열
- target_grade: ['고1', '고2', '고3', 'N수', '중등', '전체'] 중 해당하는 모두
- target_subject: ['수학', '국어', '영어', '탐구', '전체'] 중 해당하는 모두
- urgency: 'important' (즉시 학부모 상담·수업 영향) 또는 'normal'

JSON만 출력. 다른 설명 X.

예시:
{
  "source": "평가원",
  "source_detail": "한국교육과정평가원",
  "category": "모의고사",
  "summary": "2026 6월 모의평가 출제 범위 발표. 미적분 II-3까지 포함되며 함수의 극한 비중 증가 예상. 봉쌤 고2반 6월 시험 대비 수업 조정 필요.",
  "tags": ["모의평가", "6월", "미적분", "출제범위"],
  "target_grade": ["고2", "고3"],
  "target_subject": ["수학"],
  "urgency": "important"
}`;

  try {
    const response = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 500,
      messages: [{ role: 'user', content: prompt }],
    });

    const text = response.content[0].text.trim();
    const cleaned = text.replace(/```json|```/g, '').trim();
    return JSON.parse(cleaned);
  } catch (error) {
    console.error('Classification failed:', error);
    return null;
  }
}

export async function classifyBatch(newsList, concurrency = 5) {
  const results = [];
  for (let i = 0; i < newsList.length; i += concurrency) {
    const batch = newsList.slice(i, i + concurrency);
    const classified = await Promise.all(
      batch.map(async (news) => {
        const result = await classifyNews(news);
        return { ...news, ...result };
      })
    );
    results.push(...classified);
  }
  return results;
}
