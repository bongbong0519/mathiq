// Claude로 브리핑 포맷 정리
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

export async function formatBriefing({ weather, news, time }) {
  const hour = time.getHours();
  const greeting = getGreeting(hour);
  const dateStr = formatDate(time);

  const weatherText = weather
    ? `${weather.icon} 광주 ${weather.temp}°C (${weather.tempMin}~${weather.tempMax}°C) / ${weather.description} / 습도 ${weather.humidity}%`
    : '날씨 정보 없음';

  const newsText = news.length > 0
    ? news.map((n, i) => {
        const source = n.source || '뉴스';
        const category = n.category || '기타';
        const urgency = n.urgency === 'important' ? '🔴' : '';
        const summary = n.summary || n.description || '';
        return `${i + 1}. ${urgency}[${source}/${category}] ${n.title}\n   요약: ${summary}\n   URL: ${n.original_url || n.link}`;
      }).join('\n\n')
    : '오늘의 입시 뉴스 없음';

  const prompt = `당신은 봉쌤(현역 수학 교사 + 학원 부원장 + MathIQ 운영자)의 개인 비서입니다.
다음 정보를 바탕으로 텔레그램 메시지를 작성해주세요.

[현재 시각]
${dateStr}

[날씨]
${weatherText}

[입시·교육 뉴스 (최근 24시간, AI 분류 완료)]
${newsText}

작성 규칙:
1. 텔레그램 메시지 형식 (HTML 태그 사용 금지, 일반 텍스트만)
2. 이모지 적절히 사용
3. 뉴스 선별 기준:
   - 🔴 urgency=important 표시된 건 우선 노출
   - 학부모 상담에 직접 영향 주는 정책/제도 변경 우선
   - 카테고리 다양하게 (한 카테고리 3개 이상 X)
   - 최대 5개
4. 단순 의견 기사·중복·낚시성 헤드라인 제외
5. 각 뉴스는 한 줄 요약 + 봉쌤 활용 포인트 1줄
6. 인사말은 "${greeting}"로 시작
7. 전체 길이 1000자 이내
8. 마지막에 오늘의 한 줄 응원이나 동기부여 메시지

출력 형식 예시:
${greeting} 봉쌤! ${dateStr}
${weatherText}

📰 오늘의 입시·교육 핫이슈
1. [정책] (제목 요약)
   → 봉쌤 활용: (어떻게 쓸지)
...

💪 (응원 메시지)`;

  const response = await client.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 2000,
    messages: [{ role: 'user', content: prompt }],
  });

  return response.content[0].text;
}

function getGreeting(hour) {
  if (hour < 9) return '☀️ 굿모닝';
  if (hour < 12) return '🌤️ 좋은 오전';
  if (hour < 15) return '🌞 점심 잘 드셨어요';
  if (hour < 18) return '☕ 좋은 오후';
  if (hour < 21) return '🌆 좋은 저녁';
  return '🌙 늦은 시각';
}

function formatDate(date) {
  const days = ['일', '월', '화', '수', '목', '금', '토'];
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  const h = String(date.getHours()).padStart(2, '0');
  const day = days[date.getDay()];
  return `${y}-${m}-${d} (${day}) ${h}시`;
}
