# MathIQ 기능 명세서

> 최종 업데이트: 2026-04-21

MathIQ는 수학 문제은행 + 학생 관리 플랫폼입니다.  
현역 수학 선생님을 위한 서비스로, 학부모-선생님 분리 설계가 특징입니다.

---

## 역할별 기능 매트릭스

| 기능 | 운영자 | 원장 | 선생님 | 학부모 | 학생 |
|------|:------:|:----:|:------:|:------:|:----:|
| 문제은행 검색/조회 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 시험지 생성 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 학생 관리 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 성적 입력/분석 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 학생 성적 리포트 PDF | ✅ | ✅ | ✅ | ✅ | ✅ |
| 학부모 문자 발송 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 과외 선생님 등록 | ❌ | ❌ | ✅ | ❌ | ❌ |
| 과외 구인 등록 | ❌ | ❌ | ❌ | ✅ | ✅ |
| 과외 매칭 신청 | ❌ | ❌ | ❌ | ✅ | ✅ |
| 매칭 수락/거절 | ❌ | ❌ | ✅ | ❌ | ❌ |
| 포인트 관리 | ✅ | ❌ | ❌ | ❌ | ❌ |
| 플랫폼 통계 | ✅ | ❌ | ❌ | ❌ | ❌ |
| 게시판 (버그/질문/건의) | ✅ | ✅ | ✅ | ✅ | ✅ |
| 1:1 문의 | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 세부 기능 문서

| 문서 | 설명 | 완성도 |
|------|------|:------:|
| [01-student-report.md](./01-student-report.md) | 학생 성적 리포트 PDF | ✅ 완료 |
| [02-parent-sms.md](./02-parent-sms.md) | 학부모 문자 발송 | ⚠️ UI만 (실제 발송 미구현) |
| [03-tutor-matching.md](./03-tutor-matching.md) | 과외 매칭 시스템 | ✅ Phase 1 완료 |
| [04-point-system.md](./04-point-system.md) | 포인트 시스템 | ✅ 완료 |
| [05-roadmap.md](./05-roadmap.md) | 장기 로드맵 | 📋 계획 |
| [06-organization-system.md](./06-organization-system.md) | 기관 시스템 설계 | 📋 설계만 (구현 예정) |
| [07-tutor-certification.md](./07-tutor-certification.md) | 선생님 인증 시스템 (등급제) | 📋 설계만 (구현 예정) |
| [08-accounting-system.md](./08-accounting-system.md) | 회계 시스템 (수강료/정산) | 📋 설계만 (구현 예정) |

### 완성도 범례
- ✅ 완료: 배포 완료, 정상 작동
- ⚠️ 부분 완료: 일부 기능 미구현 또는 제한적
- ❌ 미완료: 개발 중 또는 계획만 존재

---

## 기술 스택 요약

- **프론트엔드**: 바닐라 JavaScript (프레임워크 없음)
- **백엔드**: Supabase (PostgreSQL + Auth + Storage + RLS)
- **배포**: Vercel (main 브랜치 푸시 시 자동 배포)
- **수식 렌더링**: KaTeX
- **추가 서버**: Railway (mathiq-draw, 손글씨 인식용)

---

## 주요 URL

| 페이지 | URL | 용도 |
|--------|-----|------|
| 메인 | https://mathiq-psi.vercel.app | 대시보드 |
| 학생 리포트 | /student-report.html?student_id=xxx&exam_id=yyy | PDF 리포트 |
| 검수 시스템 | /paste-review.html | 문제 검수 (운영자) |

---

## 관련 파일

- `CLAUDE.md`: Claude Code 작업 지침
- `config.js`: Supabase 키 설정 (gitignore)
- `supabase/migrations/`: DB 마이그레이션 SQL 파일들
