# MathIQ 회계 시스템 DB 스키마

회계 기능을 위한 Supabase 마이그레이션 파일들입니다.

## 파일 목록

| 파일 | 설명 |
|------|------|
| `00_extend_profiles.sql` | profiles 테이블 확장 (사업자 정보) |
| `01_accounting_income.sql` | 수입(매출) 테이블 + RLS |
| `02_accounting_expense.sql` | 지출(비용) 테이블 + RLS |
| `03_accounting_staff_salary.sql` | 강사 관리 + 급여 테이블 (학원용) |
| `04_accounting_settings.sql` | 회계 설정 테이블 |
| `05_views.sql` | 집계 뷰 5개 |
| `99_rollback.sql` | 전체 롤백 스크립트 |

## 실행 순서

**반드시 순서대로 실행하세요!**

```
00 → 01 → 02 → 03 → 04 → 05
```

- `01`의 트리거 함수(`fn_set_updated_at`)가 `02~04`에서 재사용됨
- `05`의 뷰가 `01~03` 테이블을 참조함

## 실행 방법

1. Supabase 대시보드 접속
2. **SQL Editor** 메뉴 클릭
3. 파일 내용 복사 → 붙여넣기
4. **Run** 버튼 클릭
5. 하단 결과 확인 (검증 쿼리 결과 표시됨)

## 검증 방법

각 파일 실행 후 하단에 검증 쿼리 결과가 표시됩니다.

### 전체 검증

```sql
-- 테이블 확인
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE 'accounting%'
ORDER BY table_name;

-- 뷰 확인
SELECT table_name
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name LIKE 'v_%'
ORDER BY table_name;

-- RLS 정책 확인
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename LIKE 'accounting%'
   OR tablename = 'academy_staff'
ORDER BY tablename, policyname;
```

## 테이블 구조

### 업태별 사용 테이블

| 테이블 | 과외 | 교습소 | 학원 |
|--------|:----:|:------:|:----:|
| accounting_income | ✅ | ✅ | ✅ |
| accounting_expense | - | ✅ | ✅ |
| academy_staff | - | - | ✅ |
| accounting_staff_salary | - | - | ✅ |
| accounting_settings | ✅ | ✅ | ✅ |

### 사업자 상태

| 값 | 설명 | 세금 처리 |
|----|------|----------|
| `unregistered` | 미등록 | 종합소득세 신고 |
| `freelancer` | 프리랜서 | 3.3% 원천징수 |
| `simple_vat` | 간이과세자 | 부가세 간이 |
| `general_vat` | 일반과세자 | 부가세 일반 |

## 롤백 (되돌리기)

**주의: 모든 회계 데이터가 삭제됩니다!**

```
99_rollback.sql 실행
```

롤백 순서:
1. 뷰 삭제
2. 테이블 삭제 (데이터 포함)
3. 트리거 함수 삭제
4. profiles 확장 컬럼 삭제

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-04-23 | v1.0 | 초기 스키마 |

## 관련 문서

- [DOCS/08-accounting-system.md](../../DOCS/08-accounting-system.md) - 회계 시스템 기능 명세
