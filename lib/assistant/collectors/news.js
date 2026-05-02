// 네이버 뉴스 수집 (입시 + 교육 키워드)
const KEYWORDS = [
  '수능 출제',
  '대입 정책',
  '교육부',
  '의대 정원',
  '평가원',
  'AI 교육',
];

export async function getNews() {
  try {
    const allNews = [];

    for (const keyword of KEYWORDS) {
      const news = await searchNaverNews(keyword);
      allNews.push(...news);
    }

    // 중복 제거 (제목 기준)
    const unique = [];
    const seen = new Set();
    for (const item of allNews) {
      const titleClean = item.title.replace(/<[^>]*>/g, '');
      if (!seen.has(titleClean)) {
        seen.add(titleClean);
        unique.push({ ...item, title: titleClean });
      }
    }

    // 최근 24시간 내 + 최대 15개
    const now = Date.now();
    const dayAgo = now - 24 * 60 * 60 * 1000;

    return unique
      .filter(item => new Date(item.pubDate).getTime() > dayAgo)
      .sort((a, b) => new Date(b.pubDate) - new Date(a.pubDate))
      .slice(0, 15);
  } catch (error) {
    console.error('News fetch failed:', error);
    return [];
  }
}

async function searchNaverNews(keyword) {
  const url = `https://openapi.naver.com/v1/search/news.json?query=${encodeURIComponent(keyword)}&display=10&sort=date`;

  const response = await fetch(url, {
    headers: {
      'X-Naver-Client-Id': process.env.NAVER_CLIENT_ID,
      'X-Naver-Client-Secret': process.env.NAVER_CLIENT_SECRET,
    },
  });

  if (!response.ok) {
    throw new Error(`Naver API error: ${response.status}`);
  }

  const data = await response.json();
  return data.items.map(item => ({
    title: item.title,
    description: item.description.replace(/<[^>]*>/g, ''),
    link: item.link,
    pubDate: item.pubDate,
    keyword,
  }));
}
