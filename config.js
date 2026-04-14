const SUPABASE_URL = 'https://cmwuuksxziyemknwwvkc.supabase.co';
const SUPABASE_KEY = 'sb_publishable_e1Xu-klaPd_bZKrKsZ8YsA_WEBnRWRh';

// Gemini API 키는 Vercel 환경 변수(GEMINI_API_KEY)로 관리합니다.
// 프론트엔드는 /api/gemini 프록시를 통해 호출합니다.

// EmailJS 설정 (https://www.emailjs.com 에서 발급)
const EMAILJS_PUBLIC_KEY  = 'uEuxnjAAmPJcJMiEp';
const EMAILJS_SERVICE_ID  = 'service_eysit3g';
const EMAILJS_TPL_USER     = 'template_2upkcoi';
const EMAILJS_TPL_ADMIN    = 'template_evwa3cv';
const EMAILJS_TPL_APPROVAL = 'template_2upkcoi'; // 승인/거절 알림 (별도 템플릿 만들면 ID 교체)
const EMAILJS_TPL_CONTACT  = '';                  // 문의하기 템플릿 ID (없으면 EMAILJS_TPL_ADMIN 재사용)
