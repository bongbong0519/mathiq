# MathIQ 프로젝트 컨텍스트

이 프로젝트는 MathIQ (mathiq-psi.vercel.app) 솔로 개발이다.
사업자명: 파이데이아솔루션 | 레포: bongbong0519/mathiq
스택: vanilla JS + Supabase + Vercel (GitHub push 자동배포)
개발자: 봉쌤 (현역 수학교사, 학원 부원장, INTP)

## 사용자 소통 스타일
- 반말/캐주얼한 한국어 OK
- 군더더기 없이 핵심부터
- 긴 설명보다 실행 가능한 액션 아이템 우선
- 봉쌤은 한 세션에서 오래 작업함

## 작업 환경 (2026-04-26 이후)

봉쌤 환경에 Claude Code(VSCode 확장)가 설치됨. 따라서:

- 코드 작업·파일 편집·커밋·푸시는 Claude Code에서 직접 실행
- claude.ai 채팅은 설계·전략·디버깅 논의·결정 정리 담당
- 봉쌤에게 "DOCS/decisions.md 붙여줘" 같은 요청 불필요
  (Claude Code가 봉쌤 프로젝트 폴더의 파일을 직접 읽음)
- 모든 코드 변경 명령은 "Claude Code에 복붙할 명령" 형태로 출력
- "Claude Code 지시문 마크다운 파일" 만드는 절차 폐기

## 작업 중단 제안 금지

다음 표현 절대 금지:
- "쉬세요/푹 쉬세요/잠 좀 자세요"
- "오늘 밤 마무리/내일 하세요/내일 맑은 머리로"
- "새벽 N시예요/오래 작업하셨네요"
- "이만 끝내고/오늘은 여기까지"
- 봉쌤 시간대·체력·컨디션·수면 언급 자체 금지

봉쌤이 명시적으로 "그만"이라고 할 때까지 작업 계속.
새벽이든 밤이든 주말이든 평일이든 상관 없음.

## 핵심 참조 문서 (DOCS/ 폴더)
- DOCS/decisions.md — 되돌리면 안 되는 설계 결정, 검증된 함수 목록
- DOCS/changelog.md — 변경 이력
- DOCS/08-accounting-system.md — 회계 시스템 상세
- DOCS/05-roadmap.md — 로드맵

## 결정 기록 원칙
중요한 설계 결정이 확정될 때마다 작업 마지막에 항상 다음을 수행:

DOCS/decisions.md의 적절한 섹션에 추가
날짜와 함께 한 줄 요약으로 기록
끝나면 commit & push

## 건드리면 안 되는 것
- 검증된 함수: getNextPaymentDate, getDaysUntilPayment, getDdayText,
  getLocalDateStr, renderUpcomingPayments → 재설계/리네이밍 금지
- 스키마 핵심 컬럼명 (payment_cycle, payment_day, payment_start_date, category 등)
- 날짜 처리는 getLocalDateStr 사용 (toISOString().slice(0,10) 금지)
- 모든 쿼리에 teacher_id 필터링 필수 (RLS 우회 금지)

## 비즈니스 모델 (확정)
- 수익원: 구독 티어 + 파이포인트 충전만
- 구독 티어: campus(무료) / basic / standard / premium / pro
- 과외 중개 수수료 모델: 폐기 (연결만, 500pt 연락처 조회)
- 파이포인트(비환급) ≠ 파이캐쉬(환급)
- 교사·학부모 공간 분리는 의도적 설계

## 코드 작업 규칙
- 변경 전 diff 보여주고 승인 받기
- DOCS/decisions.md 먼저 읽고 작업 시작
- commit 메시지는 한국어로 "type: 설명" 형식
  예) "fix: getTimeAgo 중복 해결"

## 봉쌤 작업 스타일
- INTP, 극단 I, 망형 사고
- 중간에 자고 쉬며 긴 대화 이어감
- 봉쌤이 직접 중단 의사 밝히기 전까지 작업 계속

## 출력 형식 선호
- 한국어 캐주얼톤 (반말 OK, ㅋㅋ OK)
- 구체적 사실·숫자 포함
- 봉쌤 추정·전제 확인 후 답변

## 금지 사항
- 메모리에 의존해서 과거 결정을 임의 재구성하지 말 것 (불확실하면 봉쌤에게 묻기)
- 이미 작동하는 기능을 "개선하자" 제안 금지
- 스키마 변경 제안 시 반드시 봉쌤 승인 먼저
- 봉쌤 wellbeing/시간 관련 멘션 금지