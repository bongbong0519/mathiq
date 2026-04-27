# C-3 티어 자동 배정 확인

> 확인일: 2026-04-28
> 정책: 옵션 C (코드 변경 없음, 운영자 수동 처리)

## 현재 동작

가입 시 모든 사용자가 `campus` 티어로 배정됨.

| 위치 | 행 | 함수 | 코드 |
|------|-----|------|------|
| A | 7493 | loadProfile() | `subscription_tier: 'campus'` |
| B | 7790 | 회원가입 폼 처리 | `subscription_tier: 'campus'` |

## 정책 결정 (2026-04-26)

**옵션 C 채택**: 코드 변경 없이 운영자 수동 처리

- 베타 5~10명 규모라 수동 가능
- 가입 시 무조건 campus 배정
- 봉쌤이 직접 티어 변경 (Supabase Dashboard)

## 베타 후 작업 시 참조

### 가입 폼에 업태 선택 추가 시

**수정 위치**:
1. HTML: 가입 폼에 업태 선택 UI 추가
2. JS 위치 B (7785-7791행): `subscription_tier` 값을 업태에 따라 분기
3. JS 위치 A (7487-7496행): 동일하게 분기 처리 (fallback용)

**분기 로직 예시**:
```javascript
// 업태별 디폴트 티어
const BUSINESS_TYPE_TIER = {
  university_student: 'campus',
  private_tutor: 'basic',
  academy: 'basic',
  school: 'basic',
  expert: 'basic'
};

subscription_tier: BUSINESS_TYPE_TIER[selectedBusinessType] || 'basic'
```

### 관련 상수

이미 정의됨:
- `SIGNUP_BONUS` (13290행): 티어별 가입 보너스
- `TIER_ORDER` (13284행): 티어 순서

## 액션 아이템

- [ ] 가입 폼에 업태 5개 선택 UI 추가
- [ ] 업태별 디폴트 티어 분기 로직 구현
- [ ] 대학생 인증 방식 결정 (자기 신고? 학교 이메일?)
