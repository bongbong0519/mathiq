// 1시간마다 뉴스 수집 (GitHub Actions가 호출)
import { createClient } from '@supabase/supabase-js';
import crypto from 'crypto';
import { getNews } from '../../lib/assistant/collectors/news.js';
import { classifyBatch } from '../../lib/assistant/collectors/news-classifier.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

export default async function handler(req, res) {
  const authHeader = req.headers.authorization;
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    console.log('[Collect] Started');

    const news = await getNews({ hoursWindow: 1 });
    console.log(`[Collect] Fetched: ${news.length} items`);

    if (news.length === 0) {
      return res.status(200).json({ ok: true, fetched: 0 });
    }

    const urlHashes = news.map(n => crypto.createHash('md5').update(n.link).digest('hex'));
    const { data: existing } = await supabase
      .from('news_archive')
      .select('url_hash')
      .in('url_hash', urlHashes);

    const existingHashes = new Set(existing?.map(e => e.url_hash) || []);
    const newNews = news.filter((n, i) => !existingHashes.has(urlHashes[i]));

    console.log(`[Collect] New items: ${newNews.length}`);

    if (newNews.length === 0) {
      return res.status(200).json({ ok: true, fetched: news.length, new: 0 });
    }

    const classified = await classifyBatch(newNews, 5);
    const validClassified = classified.filter(c => c.source);

    console.log(`[Collect] Classified: ${validClassified.length}`);

    const records = validClassified.map(item => ({
      source: item.source,
      source_detail: item.source_detail || item.keyword,
      category: item.category,
      title: item.title.replace(/<[^>]*>/g, ''),
      summary: item.summary,
      description: item.description,
      original_url: item.link,
      published_at: new Date(item.pubDate).toISOString(),
      urgency: item.urgency || 'normal',
      tags: item.tags || [],
      target_grade: item.target_grade || ['전체'],
      target_subject: item.target_subject || ['전체'],
      is_manual: false,
      url_hash: crypto.createHash('md5').update(item.link).digest('hex'),
    }));

    const { error } = await supabase.from('news_archive').insert(records);

    if (error) {
      console.error('[Collect] DB insert error:', error);
      throw error;
    }

    console.log(`[Collect] Saved: ${records.length}`);

    res.status(200).json({
      ok: true,
      fetched: news.length,
      new: newNews.length,
      saved: records.length,
    });
  } catch (error) {
    console.error('[Collect] Failed:', error);
    res.status(500).json({ ok: false, error: error.message });
  }
}
