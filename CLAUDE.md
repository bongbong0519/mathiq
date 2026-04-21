# MathIQ 프로젝트 - Claude Code 작업 지침

## 👤 나(봉쌤)에 대해
- 현역 수학 교사, 파이데이아솔루션(Paideia Solution) 대표
- **비개발자**: 코드 직접 못 읽고 못 씀. AI에게 전적으로 의존
- 성향: INTP, 메타인지 강함. 애매한 설명보다 **명확한 체크리스트** 선호
- 기준: **"완벽하지 않으면 출시 안 함"**. 적당히 넘어가는 거 싫어함

## 🎯 MathIQ 프로젝트 개요
- URL: https://mathiq-psi.vercel.app
- 수학 문제은행 + 학생 관리 플랫폼
- 현역 수학 선생님 대상, 학부모-선생님 분리 설계
- 저작권 클린한 공공저작물(수능·모평·학평·사관학교·경찰대) 중심 구축

## 📞 나와 소통하는 방식 (중요!)
- 코드 수정 완료 후 **반드시 한국어 요약** 먼저 보고
- 기술 용어보다 **"사용자 입장에서 뭐가 달라지는지"** 설명
- 테스트 방법은 **구체적 클릭 순서**로 안내
  예시 ❌ "paste-review 페이지에서 테스트해보세요"
  예시 ✅ "1) https://mathiq-psi.vercel.app/paste-review.html 접속 
         2) Ctrl+Shift+R로 캐시 초기화
         3) Ctrl+V로 시험지 이미지 붙여넣기
         4) 카드 여러 개가 뜨면 성공"
- 에러 가능성 있으면 **미리 경고**
- 확신 안 서면 **추측 말고 질문**

## 🔧 기술 스택
- 바닐라 JavaScript + Supabase + Vercel
- GitHub: bongbong0519/mathiq (main 브랜치 푸시 시 자동 배포)
- 배포 후 테스트할 때 **Ctrl+Shift+R** 필수 (Vercel 캐시)
- KaTeX로 수식 렌더링
- 추가 Railway 서버: bongbong0519/mathiq-draw (gentle-kindness 프로젝트)

## 🔐 Supabase 설정
- Supabase 키는 **config.js** 파일에 있음 (index.html 참고)
- 사용 변수명: `SUPABASE_URL`, `SUPABASE_KEY` (ANON_KEY 아님!)
- 사용자 정보 테이블: **profiles** (users 아님)
- 운영자 role 값: **'staff'**

## 🐛 미해결 버그 (임의로 건드리지 말 것)
내가 명시적으로 수정 요청할 때만 손대기:
1. **loadDashboard**: `exams` 변수를 `recentExams` 대신 참조 → 대시보드 최근 시험 안 뜸
2. **submitUpload**: `finally` 블록 뒤 `}` 누락 → SyntaxError로 로그인 불가
3. **sgExportPDF**: 3584라인 `const a` 중복 선언 (window.open 블록 잔존)

## 📋 작업 원칙
1. 기존 index.html의 코딩 스타일(들여쓰기, 네이밍, 주석) 그대로 따를 것
2. 확신 안 서면 **추측하지 말고 질문**
3. 큰 변경 시 `git diff` 요약을 한국어로 보여준 뒤 커밋
4. 커밋 메시지는 한국어 OK (예: `fix: 로그인 오류 수정`, `feat: 검수 UI 추가`)
5. DB 스키마 변경, 인증 로직 변경, 결제 관련은 **반드시 나에게 확인 받기**
6. 환경변수(API 키 등) 필요하면 먼저 알려주기 — 내가 Vercel에 설정해야 함

## 📌 현재 전략 (2026-04-20 기준)
- **AI 자동 추출 포기** → 공공저작물 중심 수동 검수로 전환
- `paste-review.html` + `api/extract-page.js`로 Ctrl+V 페이지 검수 시스템 도입
- **답 자동 추정 금지** (Claude가 이미지 보고 답 추정하면 오답 생성)
- 목표: 수능 33년·모평·학평·사관학교·경찰대 약 8,000~10,000 문제 수집

## 🤝 과외 매칭 시스템 (Phase 1 완료, 2026-04-21)

### 현재 구현된 기능
- **학부모 → 선생님 매칭 신청** (무료)
- **선생님 수락** (500P 차감) → 양쪽 연락처 공개
- **학부모 성사 신고** (500P 리워드)
- 복수 과목/지역 선택 (tutee_profiles, tutor_profiles 모두 배열)

### 알려진 한계 (Phase 1.5+ 예정)
- ❌ **알림 시스템 없음**: 신청/수락 시 이메일 또는 앱내 알림 없음. 당사자가 직접 대시보드 확인 필요
- ❌ **선생님→학생 역방향 신청 미지원**: 현재는 학부모만 신청 가능
- ❌ **채팅/메시지 없음**: 연락처 공개 후 외부 연락 필요

### 관련 테이블
- `tutor_profiles`: 선생님 과외 프로필
- `tutee_profiles`: 학생/학부모 구인 프로필  
- `tutor_match_requests`: 매칭 신청 (pending/accepted/rejected/cancelled)
- `tutor_matches`: 성사된 매칭 기록
- `tutor_contact_views`: ~~기존 연락처 열람 기록~~ **(Phase 1에서 DROP됨)**

## 💰 비용 주의
- 모든 API 호출은 과금됨 (Anthropic, Gemini)
- 불필요한 반복 호출 자제
- 큰 이미지·긴 응답 필요 시 미리 알려주기

## 🚫 하지 말 것
- 내가 요청 안 한 리팩토링
- "더 나은 구조" 제안 후 임의 적용 (제안은 환영, 실행은 승인 후)
- 기존 기능 임의 제거
- `node_modules`, `package-lock.json` 등 거대 파일 커밋
- 내 개인정보/API 키 커밋 (config.js는 .gitignore 확인)
