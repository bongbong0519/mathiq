// 텔레그램 메시지 발송
export async function sendTelegram(message) {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;

  const url = `https://api.telegram.org/bot${token}/sendMessage`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text: message,
      disable_web_page_preview: false,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Telegram send failed: ${error}`);
  }

  return response.json();
}
