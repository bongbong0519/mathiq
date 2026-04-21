# 학부모 문자 발송

> 최종 업데이트: 2026-04-21  
> 상태: ⚠️ UI만 구현 (실제 발송은 사업자등록 후 예정)

---

## 목적

선생님이 학부모에게 성적, 출결, 숙제 등의 알림을 문자로 보낼 수 있습니다.  
현재는 UI와 발송 기록 저장만 구현되어 있고, 실제 SMS 발송은 미구현입니다.

---

## 사용자

- **선생님/원장**: 학생 관리 → 학생 선택 → "학부모 문자" 버튼

---

## 메시지 유형 (4가지)

| 유형 | 코드 | 설명 | 템플릿 예시 |
|------|------|------|-------------|
| 성적 통보 | `grade` | 시험 결과 알림 | "{학생명}님의 {시험명} 결과: {점수}점" |
| 출결 알림 | `attendance` | 출석/결석/지각 | "{학생명}님이 오늘 {상태}하였습니다" |
| 숙제 알림 | `homework` | 숙제 미제출 등 | "{학생명}님의 숙제가 미제출입니다" |
| 자유 입력 | `custom` | 직접 작성 | (선생님 자유 입력) |

---

## 기능 상세

### 1. 학생 다중 선택
- 체크박스로 여러 학생 선택 가능
- "전체 선택" 버튼 제공
- 선택된 학생 수 실시간 표시

### 2. 템플릿 변수 치환
메시지에서 자동 치환되는 변수:

| 변수 | 치환값 |
|------|--------|
| `{학생명}` | 학생 이름 |
| `{시험명}` | 선택한 시험 이름 |
| `{점수}` | 해당 학생 점수 |
| `{석차}` | 해당 학생 석차 |
| `{선생님명}` | 발송 선생님 이름 |

### 3. 글자 수 표시
- 실시간 글자 수 카운트
- SMS: 90자 / LMS: 2000자 기준 안내
- 변수 치환 후 예상 글자 수도 표시

### 4. 리포트 URL 첨부 (선택)
- "성적 리포트 링크 포함" 체크박스
- 체크 시 메시지 끝에 리포트 URL 자동 추가

---

## 플로우

```
1. 학생 관리 페이지 진입
2. 학생 선택 (다중 가능)
3. "학부모 문자" 버튼 클릭
4. 메시지 유형 선택
5. 메시지 작성 (또는 템플릿 사용)
6. 미리보기 확인
7. "발송" 클릭
8. sms_history에 기록 저장 (status: 'pending')
```

---

## 데이터베이스

### students 테이블 추가 컬럼
| 컬럼 | 타입 | 설명 |
|------|------|------|
| parent_phone | TEXT | 학부모 연락처 |
| parent_name | TEXT | 학부모 이름 |

### sms_history 테이블
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| sender_id | UUID | 보낸 선생님 (FK → profiles) |
| student_id | UUID | 대상 학생 (FK → students) |
| recipient_phone | TEXT | 받는 번호 |
| message_type | TEXT | grade/attendance/homework/custom |
| message_content | TEXT | 실제 메시지 내용 |
| related_exam_id | UUID | 관련 시험 (성적 통보 시) |
| include_report_url | BOOLEAN | 리포트 URL 포함 여부 |
| status | TEXT | pending/sent/failed |
| scheduled_at | TIMESTAMPTZ | 예약 발송 시간 |
| sent_at | TIMESTAMPTZ | 실제 발송 시간 |
| error_message | TEXT | 실패 시 오류 메시지 |
| created_at | TIMESTAMPTZ | 생성 시간 |

---

## RLS 정책

| 정책 | 대상 | 권한 |
|------|------|------|
| teacher_sms_select | 선생님 | 본인 발송 기록 조회 |
| teacher_sms_insert | 선생님 | 본인 발송 기록 생성 |
| staff_sms_select | 운영자 | 전체 조회 |
| staff_sms_update | 운영자 | 상태 업데이트 (발송 처리) |

---

## 실제 발송 구현 계획

### 필요 조건
1. 사업자등록 완료
2. SMS 발송 API 계약 (예: NHN Cloud, 알리고, 네이버 클라우드)
3. 발신번호 등록

### 구현 방식 (예정)
1. Vercel Edge Function 또는 Supabase Edge Function
2. sms_history에서 status='pending' 레코드 조회
3. SMS API 호출
4. 결과에 따라 status 업데이트 (sent/failed)

---

## 주의사항

- **현재는 발송 기록만 저장됨** (실제 문자 안 감)
- 학생에 parent_phone이 없으면 발송 불가
- 대량 발송 시 API 비용 주의 (건당 과금)
- 스팸 방지를 위해 일일 발송 한도 설정 필요 (미구현)
