// 메인 엔드포인트 (Vercel Cron 호출 대상)
import { getWeather } from '../../lib/assistant/collectors/weather.js';
import { getNews } from '../../lib/assistant/collectors/news.js';
import { formatBriefing } from '../../lib/assistant/formatter.js';
import { sendTelegram } from '../../lib/assistant/telegram.js';

export default async function handler(req, res) {
  // Vercel Cron 인증 (필요시)
  if (req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`
      && process.env.NODE_ENV === 'production') {
    // CRON_SECRET 설정 안 했으면 이 체크 건너뜀
    if (process.env.CRON_SECRET) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
  }

  try {
    const now = new Date();

    // 한국 시간 보정 (Vercel은 UTC)
    const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);

    console.log(`[Briefing] Started at ${kstNow.toISOString()}`);

    // 병렬로 데이터 수집
    const [weather, news] = await Promise.all([
      getWeather(),
      getNews(),
    ]);

    console.log(`[Briefing] Collected: weather=${!!weather}, news=${news.length}`);

    // Claude로 포맷
    const message = await formatBriefing({
      weather,
      news,
      time: kstNow,
    });

    console.log(`[Briefing] Message length: ${message.length}`);

    // 텔레그램 발송
    await sendTelegram(message);

    console.log(`[Briefing] Sent successfully`);

    res.status(200).json({
      ok: true,
      time: kstNow.toISOString(),
      newsCount: news.length,
      messageLength: message.length,
    });
  } catch (error) {
    console.error('[Briefing] Failed:', error);

    // 실패해도 텔레그램으로 알림 시도
    try {
      await sendTelegram(`⚠️ 브리핑 생성 실패\n${error.message}`);
    } catch (e) {
      console.error('[Briefing] Telegram alert also failed:', e);
    }

    res.status(500).json({ ok: false, error: error.message });
  }
}
