const SUPABASE_URL = 'https://cmwuuksxziyemknwwvkc.supabase.co';
const SUPABASE_KEY = 'sb_publishable_e1Xu-klaPd_bZKrKsZ8YsA_WEBnRWRh';

// Gemini API (문제은행 PDF 추출)
// GEMINI_API_KEY는 config.local.js에서 설정하세요 (git에 커밋되지 않음)
// const GEMINI_API_KEY = 'your-key-here';
if (typeof GEMINI_API_KEY === 'undefined') window.GEMINI_API_KEY = '';

// EmailJS 설정 (https://www.emailjs.com 에서 발급)
const EMAILJS_PUBLIC_KEY  = 'uEuxnjAAmPJcJMiEp';
const EMAILJS_SERVICE_ID  = 'service_eysit3g';
const EMAILJS_TPL_USER     = 'template_2upkcoi';
const EMAILJS_TPL_ADMIN    = 'template_evwa3cv';
const EMAILJS_TPL_APPROVAL = 'template_2upkcoi'; // 승인/거절 알림 (별도 템플릿 만들면 ID 교체)
const EMAILJS_TPL_CONTACT  = '';                  // 문의하기 템플릿 ID (없으면 EMAILJS_TPL_ADMIN 재사용)
