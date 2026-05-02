// 메인 엔드포인트 (Vercel Cron 호출 대상)
import { createClient } from '@supabase/supabase-js';
import { getWeather } from '../../lib/assistant/collectors/weather.js';
import { formatBriefing } from '../../lib/assistant/formatter.js';
import { sendTelegram } from '../../lib/assistant/telegram.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function getRecentNews() {
  const hoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase
    .from('news_archive')
    .select('*')
    .gte('collected_at', hoursAgo)
    .order('published_at', { ascending: false })
    .limit(20);

  if (error) {
    console.error('[Briefing] DB query error:', error);
    return [];
  }

  return data || [];
}

export default async function handler(req, res) {
  if (req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`
      && process.env.NODE_ENV === 'production') {
    if (process.env.CRON_SECRET) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
  }

  try {
    const now = new Date();
    const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);

    console.log(`[Briefing] Started at ${kstNow.toISOString()}`);

    const [weather, news] = await Promise.all([
      getWeather(),
      getRecentNews(),
    ]);

    console.log(`[Briefing] Collected: weather=${!!weather}, news=${news.length}`);

    const message = await formatBriefing({
      weather,
      news,
      time: kstNow,
    });

    console.log(`[Briefing] Message length: ${message.length}`);

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

    try {
      await sendTelegram(`⚠️ 브리핑 생성 실패\n${error.message}`);
    } catch (e) {
      console.error('[Briefing] Telegram alert also failed:', e);
    }

    res.status(500).json({ ok: false, error: error.message });
  }
}
