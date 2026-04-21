# 포인트 시스템

> 최종 업데이트: 2026-04-21

---

## 목적

MathIQ 플랫폼 내 가상 화폐 시스템입니다.  
유료 기능 사용, 리워드 지급, 과외 매칭 비용 등에 활용됩니다.

---

## 포인트 종류

### 파이포인트 (Pi Point)
- **용도**: 플랫폼 내 기능 사용
- **획득**: 활동 리워드, 이벤트, 프로모션
- **특징**: 현금 환전 불가, 유효기간 있음 (예정)

### 파이캐쉬 (Pi Cash) - 예정
- **용도**: 프리미엄 기능, 과외 매칭 등
- **획득**: 실제 결제 (카드, 계좌이체)
- **특징**: 환불 가능 (결제 취소 시)
- **상태**: 미구현 (사업자등록 후 예정)

> 현재는 파이포인트만 운영 중입니다.

---

## 포인트 적립/차감 시점

### 적립 (+)
| 시점 | 금액 | 대상 | 설명 |
|------|:----:|------|------|
| 회원가입 | +1,000P | 전체 | 신규 가입 보너스 |
| 매칭 성사 신고 | +500P | 학부모 | 과외 매칭 성사 리워드 |
| 출석 체크 | +10P | 전체 | 일일 출석 (예정) |
| 문제 제보 | +50P | 전체 | 오류 문제 신고 (예정) |
| 리뷰 작성 | +100P | 학부모 | 선생님 리뷰 (예정) |

### 차감 (-)
| 시점 | 금액 | 대상 | 설명 |
|------|:----:|------|------|
| 매칭 수락 | -500P | 선생님 | 과외 매칭 수락 시 |
| 프로필 상위 노출 | -1,000P | 선생님 | 검색 상단 노출 (예정) |
| 프리미엄 문제 열람 | -100P | 선생님 | 고급 문제 접근 (예정) |

---

## 데이터베이스

### profiles 테이블 컬럼
| 컬럼 | 타입 | 설명 |
|------|------|------|
| point_balance | INTEGER | 현재 보유 포인트 |

### point_history 테이블 (예정)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| user_id | UUID | FK → profiles |
| amount | INTEGER | 변동량 (+/-) |
| balance_after | INTEGER | 변동 후 잔액 |
| reason | TEXT | 사유 (매칭수락, 성사신고 등) |
| related_id | UUID | 관련 레코드 ID |
| created_at | TIMESTAMPTZ | 발생 시간 |

> 현재는 point_history 없이 profiles.point_balance만 관리 중

---

## RPC 함수

### deduct_points(p_user_id, p_amount, p_reason)

포인트 차감 함수입니다.

```sql
-- 호출 예시
SELECT deduct_points(
  '사용자-uuid',
  500,
  '매칭 수락'
);
```

**특징:**
- SECURITY DEFINER: RLS 우회하여 직접 UPDATE
- 잔액 부족 시 예외 발생 (`insufficient_points`)
- 음수 잔액 방지

**에러 처리:**
```javascript
try {
  await sbClient.rpc('deduct_points', {
    p_user_id: userId,
    p_amount: 500,
    p_reason: '매칭 수락'
  });
} catch (err) {
  if (err.message.includes('insufficient_points')) {
    showToast('포인트가 부족합니다');
  }
}
```

### add_points(p_user_id, p_amount, p_reason)

포인트 지급 함수입니다.

```sql
-- 호출 예시
SELECT add_points(
  '사용자-uuid',
  500,
  '매칭 성사 리워드'
);
```

**특징:**
- SECURITY DEFINER: RLS 우회
- 사용자 없으면 예외 발생 (`user_not_found`)

---

## 포인트 표시

### UI 위치
- 상단 헤더 (로그인 시): "🪙 1,500P"
- 프로필 페이지: 잔액 + 내역 (예정)
- 매칭 수락 버튼: "수락 (500P 차감)"

### 부족 시 UX
- 수락 버튼 비활성화
- "포인트 부족 - 충전하기" 안내
- 충전 페이지 연결 (예정)

---

## 향후 계획

### 단기 (Phase 1.5)
- point_history 테이블 추가
- 포인트 내역 조회 UI
- 유효기간 관리 (180일)

### 중기 (Phase 2)
- 파이캐쉬 도입 (실결제)
- 결제 페이지 (PG 연동)
- 환불 처리

### 장기 (Phase 3)
- 포인트 선물하기
- 그룹 포인트 (학원 단위)
- 포인트몰 (상품 교환)

---

## 주의사항

- **직접 UPDATE 금지**: 반드시 RPC 함수 사용
- **동시성**: 여러 트랜잭션 동시 발생 시 race condition 가능 (추후 개선)
- **감사 로그**: 현재 point_history 없음. 분쟁 시 추적 어려움
- **마이너스 방지**: deduct_points에서 잔액 체크하지만, 동시 호출 시 음수 가능
