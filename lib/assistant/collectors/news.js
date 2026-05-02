// 네이버 뉴스 수집 (입시 + 교육 키워드 39개)
const KEYWORDS = [
  // 정부·공식 기관
  '교육부', '한국교육과정평가원', 'EBSi 수능',

  // 모의고사·시험
  '전국연합학력평가', '학력평가 출제', '수능 모의평가',
  '6월 모의평가', '9월 모의평가',

  // 입시 핵심
  '수능 출제', '대입 정책', '대입 전형', '정시 수시',

  // 의대
  '의대 정원', '의대 입시',

  // 시도교육청
  '서울특별시교육청', '경기도교육청', '부산광역시교육청', '인천광역시교육청',
  '광주광역시교육청', '대구광역시교육청', '대전광역시교육청', '세종특별자치시교육청',

  // 주요 대학
  '서울대 입시', '연세대 입시', '고려대 입시', 'KAIST 입시', 'POSTECH 입시',

  // 지거국
  '전남대 입시', '부산대 입시', '경북대 입시', '충남대 입시',
  '지방 국립대 입시',

  // 특목고
  '영재학교', '과학고 입시', '자사고 입시', '외국어고 입시', '국제고 입시',

  // 입시 데이터
  '수능 등급컷', '정시 합격선',
];

export async function getNews({ hoursWindow = 24 } = {}) {
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

    // 시간 윈도우 내 + 최대 50개
    const now = Date.now();
    const windowAgo = now - hoursWindow * 60 * 60 * 1000;

    return unique
      .filter(item => new Date(item.pubDate).getTime() > windowAgo)
      .sort((a, b) => new Date(b.pubDate) - new Date(a.pubDate))
      .slice(0, 50);
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
