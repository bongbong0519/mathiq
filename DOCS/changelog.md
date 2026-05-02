# 업데이트 이력

MathIQ의 주요 업데이트 내역입니다.

---

## 2026-05-01

### 큰 변경
- **방향 전환:** 베타(지인 10명 카톡) 취소 → 정상 오픈 목표로 전환
  - 점검 순서: 강사 → 원장 → 학생 → 정상 오픈
- **C-1 외래키 처리 9개 풀세트 완료**
  - 학생 삭제 시 데이터 보호 전면 정비
  - 박제 칼럼 패턴 도입 (학생 정보 시점 보존)

### 코드 변경
- I-13 + I-14 학생 전화 추가 + 전화 형식 통일 (커밋 fde4ad9)
  - students.student_phone 칼럼 추가
  - 자동 하이픈 입력 (010-XXXX-XXXX)
  - DB 저장은 숫자만
  - formatPhone(), autoHyphenPhone() 공통 함수
- I-16 전화 중복/일치 경고
  - 학생 전화 중복 시 confirm
  - 학부모=학생 전화 일치 시 confirm
  - 자기 자신 수정 시 제외
- C-1 박제 코드 5개 함수 수정
  - sendBillingInvoice (청구) - studentName 파라미터 제거, DB 조회 + 박제
  - sendPaymentReminder (독촉) - 동일 패턴
  - startExam (시험 시작) - exam_sessions INSERT 시 박제
  - submitMaterialShare (자료 공유) - 일괄 INSERT 시 박제 + 검증
  - smsSendMessages (학부모 문자) - records 배열에 student_name_snapshot

### DB 변경 (Supabase 직접 실행)
- 박제 칼럼 추가 (8개 테이블)
  - billing_invoices: student_name/student_phone/parent_phone snapshot
  - exam_results: student_name/grade/school/teacher_id snapshot
  - exam_sessions: student_name/grade/school/teacher_id snapshot
  - material_shares: student_name/grade/school snapshot
  - payment_reminders: student_name/student_phone/parent_phone snapshot
  - sms_history: student_name snapshot
  - teacher_comments: student_name/grade snapshot
- student_id NULL 허용 (해당 테이블)
- ON DELETE CASCADE → SET NULL 변경 (해당 테이블)
- accounting_income 더미 데이터 5건 정리 (박지훈 외 4명, 학생 매칭 불가)
- sms_history message_type CHECK 제약 제거 (I-20 임시 조치)

### 새 점검 이슈 발견
- I-15 학부모 이름 입력 UI 누락
- I-17 성적 리포트 강사 정보 표시 정책
- I-18 자료 공유 취소/회수 기능
- I-19 청구/독촉 SMS sms_history INSERT 누락
- I-20 sms_history CHECK 제약 안전한 형태로 다시
- I-21 SMS 발송 이력 권한 분리 확인
- I-22 강사 코멘트 작성 기능 구현

---

## 2026-04-27

### 문서 정리
- 점검 이슈 번호 체계 정리: 카테고리 prefix 도입 (C-N / I-N / M-N)
  - 기존 P0 단일 번호와 점검 종합 내부 번호가 섞여 #15, #16, #17, #18 중복 발생
  - 카테고리별 prefix로 충돌 해소
  - 해결 완료 이슈는 roadmap.md 별도 히스토리 섹션으로 분리

---

## 2026-04-26

### 🔧 버그 수정
- 자물쇠 모달 닫기 불가 → X/닫기/ESC/배경클릭 모두 작동
- 승인 대기 탭 비활성 → pending 사용자 쿼리 활성화

### 📋 정책 확정
- 권한 매트릭스 시스템 (19개 직원 형태 × 12개 권한 카테고리)
- 메일 시스템 처리 방향 (베타 전/후 구분)
- 티어 자동 배정 → 수동 처리 (옵션 C)
- 출결 시스템 시장 조사 결과 기록

### 🗃️ DB 정리
- 테스트 사용자 18명 삭제 (admin 1명만 보존)
- 외래키 의존성 진단 완료 (37개 테이블)
- auth.users 유령 계정 정리

### 📝 문서화
- decisions.md: 5개 섹션 추가
- roadmap.md: P0 완료 + 이슈 분류 업데이트
- 점검 daily note 작성

---

## 2026-04-23

### 🎉 신규 기능
- 계정 복구 요청 관리 페이지 추가
- 운영자 대시보드에 복구 요청 배지 표시
- 포인트 추가 복구 요청 (이의제기) 기능
- 사용설명서 페이지 (help.html) 추가
- **캠퍼스 티어 시스템**
  - 무료 캠퍼스 티어: 학생 3명, AI 5회/월 제한
  - 티어별 기능 잠금 (회계, PDF 내보내기 등)
  - 사이드바/상단바 티어 배지 표시
  - 신규 가입자 1,000P 보너스 지급

### 🔧 버그 수정
- 전체 학생 페이지 UI 렌더링 오류 수정
- 운영자 대시보드 400 에러 해결
- teacher_id NULL 학생 조회 실패 수정

---

## 2026-04-22

### 🎉 신규 기능
- 수강료 청구 시스템
- 회계 관리 (매출/지출)
- 수강생 정산 리포트

### 💡 UX 개선
- 청구서 UI 개선
- 모바일 반응형 최적화

---

## 2026-04-21

### 🎉 신규 기능
- 과외 매칭 시스템 Phase 1
- 게시판 + 1:1 문의 시스템
- 계정 탈퇴 및 복구 시스템

### 🔧 버그 수정
- 로그인 세션 유지 개선
- 프로필 이미지 업로드 오류 수정

---

## 2026-04-20

### 🎉 신규 기능
- 학생 관리 시스템
- 시험지 분석 AI
- 성적 리포트 PDF

### 💡 UX 개선
- 다크모드 지원
- 크림톤/코랄핑크 테마 적용
