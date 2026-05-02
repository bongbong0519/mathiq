// 봉쌤 수동 입력 시 즉시 텔레그램 발송
import { sendTelegram } from '../../lib/assistant/telegram.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const item = req.body;

  const urgencyMark = item.urgency === 'important' ? '🔴 ' : '';
  const message = `📌 봉쌤 직접 큐레이션
━━━━━━━━━━━━━━━━━━━

${urgencyMark}[${item.source}/${item.category}] ${item.title}

${item.summary}

🏷️ ${(item.tags || []).map(t => '#' + t).join(' ')}
🔗 ${item.original_url}`;

  try {
    await sendTelegram(message);
    res.status(200).json({ ok: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}
