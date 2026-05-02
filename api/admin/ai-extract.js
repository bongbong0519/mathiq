// URL 받아서 Claude로 자동 분석
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const { url } = req.body;
  if (!url) return res.status(400).json({ error: 'URL required' });

  try {
    const pageRes = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; MathIQ/1.0)' }
    });
    const html = await pageRes.text();

    const text = html
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .substring(0, 5000);

    const response = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 800,
      messages: [{
        role: 'user',
        content: `다음 웹페이지 내용을 분석해서 JSON으로 출력하세요.

URL: ${url}
내용: ${text}

출력 형식:
{
  "title": "기사/공지 제목",
  "summary": "봉쌤(현역 수학 교사+학원 부원장+MathIQ 운영자)이 학부모 상담·수업·MathIQ 콘텐츠에 어떻게 활용할지 2~3줄 요약",
  "source": "교육부/평가원/시도교육청/대학/특목고/대교협/EBSi/뉴스기관/기타 중 하나",
  "category": "정책/모의고사/수능/입시/특목고/대학/의대 중 하나",
  "tags": ["핵심", "키워드", "3-5개"]
}

JSON만 출력. 설명 X.`
      }],
    });

    const result = JSON.parse(response.content[0].text.replace(/```json|```/g, '').trim());
    res.status(200).json(result);
  } catch (error) {
    console.error('AI extract failed:', error);
    res.status(500).json({ error: error.message });
  }
}
