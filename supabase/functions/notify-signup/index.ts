import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? ''
const FROM_EMAIL     = Deno.env.get('FROM_EMAIL') ?? 'MathIQ <noreply@mathiq.co.kr>'
const ADMIN_EMAIL    = 'yoonbro1927@gmail.com'

const ROLE_LABEL: Record<string, string> = {
  teacher: '선생님',
  director: '원장님',
  student: '학생',
  parent: '학부모',
  admin: '운영자',
}

async function sendEmail(to: string, subject: string, html: string): Promise<boolean> {
  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ from: FROM_EMAIL, to, subject, html }),
    })
    if (!res.ok) {
      const body = await res.text()
      console.error('Resend error:', res.status, body)
    }
    return res.ok
  } catch (e) {
    console.error('sendEmail failed:', e)
    return false
  }
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const { userName, userEmail, userRole, orgName } = await req.json()

    if (!userName || !userEmail || !userRole) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const roleName   = ROLE_LABEL[userRole] ?? userRole
    const isPending  = userRole === 'teacher' || userRole === 'director'
    const orgLine    = orgName ? `<tr><td style="padding:6px 0;color:#888;width:72px">소속 기관</td><td style="font-weight:600">${orgName}</td></tr>` : ''

    // ── 1. 가입자 이메일 ──────────────────────────────────────────
    const userSubject = '[MathIQ] 가입 신청이 완료되었습니다'
    const userHtml = `
<!DOCTYPE html>
<html lang="ko">
<body style="margin:0;padding:0;background:#f5f5f5;font-family:'Apple SD Gothic Neo',Arial,sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 0">
    <tr><td align="center">
      <table width="480" cellpadding="0" cellspacing="0"
             style="background:#fff;border-radius:12px;padding:36px 32px;box-shadow:0 2px 12px rgba(0,0,0,.07)">
        <tr>
          <td style="padding-bottom:24px;border-bottom:1px solid #eee">
            <span style="font-size:22px;font-weight:800;letter-spacing:-0.5px">
              Math<span style="color:#4f8ef7">IQ</span>
            </span>
          </td>
        </tr>
        <tr>
          <td style="padding-top:24px">
            <p style="font-size:16px;font-weight:700;margin:0 0 12px">안녕하세요, ${userName}님!</p>
            <p style="font-size:14px;color:#555;line-height:1.8;margin:0 0 20px">
              <b>${roleName}</b>으로 가입 신청이 완료되었습니다.
              ${isPending
                ? '운영자 확인 후 <b>1~2 영업일 내</b>에 승인 처리됩니다.<br>승인 완료 전까지는 플랫폼 이용이 제한됩니다.'
                : '지금 바로 MathIQ를 이용하실 수 있습니다.'}
            </p>
            ${isPending ? `
            <table style="background:#f0f6ff;border-radius:8px;padding:14px 16px;width:100%;margin-bottom:20px" cellpadding="0" cellspacing="0">
              <tr>
                <td style="font-size:13px;color:#4f8ef7;font-weight:700">⏳ 승인 대기 중</td>
              </tr>
              <tr>
                <td style="font-size:12px;color:#666;margin-top:4px;padding-top:6px">
                  이메일 인증 완료 후 운영자 승인을 기다려 주세요.
                </td>
              </tr>
            </table>` : ''}
          </td>
        </tr>
        <tr>
          <td style="padding-top:24px;border-top:1px solid #eee;font-size:12px;color:#aaa">
            문의: contact@paideiaedu.com &nbsp;|&nbsp; &copy; 2026 파이데이아에듀
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`

    // ── 2. 운영자 알림 이메일 ─────────────────────────────────────
    const adminSubject = `[MathIQ] 새 가입 신청 — ${userName} (${roleName})`
    const adminHtml = `
<!DOCTYPE html>
<html lang="ko">
<body style="margin:0;padding:0;background:#f5f5f5;font-family:'Apple SD Gothic Neo',Arial,sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 0">
    <tr><td align="center">
      <table width="480" cellpadding="0" cellspacing="0"
             style="background:#fff;border-radius:12px;padding:36px 32px;box-shadow:0 2px 12px rgba(0,0,0,.07)">
        <tr>
          <td style="padding-bottom:20px;border-bottom:1px solid #eee">
            <span style="font-size:22px;font-weight:800;letter-spacing:-0.5px">
              Math<span style="color:#4f8ef7">IQ</span>
            </span>
            <span style="font-size:13px;color:#888;margin-left:10px">관리자 알림</span>
          </td>
        </tr>
        <tr>
          <td style="padding-top:20px">
            <p style="font-size:15px;font-weight:700;margin:0 0 16px">새로운 회원 가입 신청이 있습니다</p>
            <table style="font-size:14px;width:100%;border-collapse:collapse">
              <tr><td style="padding:6px 0;color:#888;width:72px">이름</td><td style="font-weight:600">${userName}</td></tr>
              <tr><td style="padding:6px 0;color:#888">이메일</td><td>${userEmail}</td></tr>
              <tr><td style="padding:6px 0;color:#888">역할</td>
                <td><span style="background:#eef4ff;color:#4f8ef7;font-size:12px;font-weight:700;padding:2px 8px;border-radius:4px">${roleName}</span></td>
              </tr>
              ${orgLine}
            </table>
            ${isPending ? `
            <p style="margin-top:20px;font-size:13px;color:#555;background:#fffbeb;border-left:3px solid #f59e0b;padding:10px 14px;border-radius:0 6px 6px 0">
              이 회원은 <b>승인 대기</b> 상태입니다. 관리자 페이지에서 승인/거절하세요.
            </p>` : ''}
          </td>
        </tr>
        <tr>
          <td style="padding-top:24px;border-top:1px solid #eee;font-size:12px;color:#aaa">
            &copy; 2026 파이데이아에듀 &nbsp;|&nbsp; 이 메일은 자동 발송됩니다
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`

    const [userOk, adminOk] = await Promise.all([
      sendEmail(userEmail, userSubject, userHtml),
      sendEmail(ADMIN_EMAIL, adminSubject, adminHtml),
    ])

    return new Response(
      JSON.stringify({ ok: true, userEmail: userOk, adminEmail: adminOk }),
      { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  } catch (e) {
    console.error('notify-signup error:', e)
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
