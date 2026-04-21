-- ══════════════════════════════════════════════════════════════════
--  수업 자료 기능 - DB 스키마
--
--  실행 순서: 섹션 1 → 2 → 3 순서대로
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 1: class_materials 테이블 (선생님 자료)                    │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.class_materials (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id    UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title         TEXT        NOT NULL,
  description   TEXT,
  file_url      TEXT        NOT NULL,
  file_name     TEXT        NOT NULL,
  file_type     TEXT,       -- pdf, image, document
  file_size     BIGINT,     -- bytes
  folder_path   TEXT        DEFAULT '',  -- 예: "지수와 로그/기본"
  tags          TEXT[],
  created_at    TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_materials_teacher ON public.class_materials(teacher_id);
CREATE INDEX IF NOT EXISTS idx_materials_folder ON public.class_materials(teacher_id, folder_path);
CREATE INDEX IF NOT EXISTS idx_materials_created ON public.class_materials(created_at DESC);

-- RLS 활성화
ALTER TABLE public.class_materials ENABLE ROW LEVEL SECURITY;

-- 선생님: 본인 자료 전체 관리
DROP POLICY IF EXISTS "materials_teacher_all" ON public.class_materials;
CREATE POLICY "materials_teacher_all"
  ON public.class_materials FOR ALL
  TO authenticated
  USING (teacher_id = auth.uid())
  WITH CHECK (teacher_id = auth.uid());

-- staff: 전체 조회
DROP POLICY IF EXISTS "materials_staff_select" ON public.class_materials;
CREATE POLICY "materials_staff_select"
  ON public.class_materials FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'staff'
    )
  );


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 2: material_shares 테이블 (학생 공유)                      │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.material_shares (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  material_id   UUID        REFERENCES public.class_materials(id) ON DELETE CASCADE NOT NULL,
  student_id    UUID        REFERENCES public.students(id) ON DELETE CASCADE NOT NULL,
  shared_by     UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  viewed_at     TIMESTAMPTZ,    -- 학생이 열람한 시점
  downloaded_at TIMESTAMPTZ,    -- 학생이 다운로드한 시점
  shared_at     TIMESTAMPTZ DEFAULT now() NOT NULL,
  UNIQUE(material_id, student_id)
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_shares_student ON public.material_shares(student_id);
CREATE INDEX IF NOT EXISTS idx_shares_material ON public.material_shares(material_id);
CREATE INDEX IF NOT EXISTS idx_shares_shared_at ON public.material_shares(shared_at DESC);

-- RLS 활성화
ALTER TABLE public.material_shares ENABLE ROW LEVEL SECURITY;

-- 선생님: 본인이 공유한 것 또는 본인 자료 공유 내역
DROP POLICY IF EXISTS "shares_teacher_select" ON public.material_shares;
CREATE POLICY "shares_teacher_select"
  ON public.material_shares FOR SELECT
  TO authenticated
  USING (
    shared_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.class_materials
      WHERE id = material_id AND teacher_id = auth.uid()
    )
  );

-- 선생님: 본인 자료에 대한 공유 생성
DROP POLICY IF EXISTS "shares_teacher_insert" ON public.material_shares;
CREATE POLICY "shares_teacher_insert"
  ON public.material_shares FOR INSERT
  TO authenticated
  WITH CHECK (
    shared_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.class_materials
      WHERE id = material_id AND teacher_id = auth.uid()
    )
  );

-- 선생님: 본인 자료 공유 삭제
DROP POLICY IF EXISTS "shares_teacher_delete" ON public.material_shares;
CREATE POLICY "shares_teacher_delete"
  ON public.material_shares FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.class_materials
      WHERE id = material_id AND teacher_id = auth.uid()
    )
  );

-- 학생: 본인에게 공유된 자료 조회
DROP POLICY IF EXISTS "shares_student_select" ON public.material_shares;
CREATE POLICY "shares_student_select"
  ON public.material_shares FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.students
      WHERE id = student_id AND (
        auth_user_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'student')
      )
    )
  );

-- 학생: 본인 공유 열람/다운로드 시간 업데이트
DROP POLICY IF EXISTS "shares_student_update" ON public.material_shares;
CREATE POLICY "shares_student_update"
  ON public.material_shares FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.students
      WHERE id = student_id AND auth_user_id = auth.uid()
    )
  );

-- staff: 전체 조회
DROP POLICY IF EXISTS "shares_staff_select" ON public.material_shares;
CREATE POLICY "shares_staff_select"
  ON public.material_shares FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'staff'
    )
  );


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 3: Storage 버킷 생성 (SQL로 불가 - 대시보드에서 수동 생성)   │
-- └─────────────────────────────────────────────────────────────────┘

-- ⚠️ Storage 버킷은 SQL로 생성 불가!
-- Supabase 대시보드 > Storage > New bucket 에서 수동 생성 필요:
--
-- 버킷 설정:
-- - Name: class-materials
-- - Public bucket: OFF (비공개)
-- - File size limit: 52428800 (50MB)
-- - Allowed MIME types:
--   application/pdf,
--   image/jpeg,
--   image/png,
--   image/gif,
--   image/webp,
--   application/msword,
--   application/vnd.openxmlformats-officedocument.wordprocessingml.document,
--   application/vnd.ms-excel,
--   application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,
--   application/vnd.ms-powerpoint,
--   application/vnd.openxmlformats-officedocument.presentationml.presentation,
--   text/plain
--
-- Storage RLS 정책 (버킷 생성 후 Policies 탭에서 설정):
--
-- 1. 선생님 업로드 허용:
--    INSERT policy: (bucket_id = 'class-materials') AND (auth.role() = 'authenticated')
--
-- 2. 선생님 본인 파일 삭제:
--    DELETE policy: (bucket_id = 'class-materials') AND (auth.uid()::text = (storage.foldername(name))[1])
--
-- 3. 인증된 사용자 읽기:
--    SELECT policy: (bucket_id = 'class-materials') AND (auth.role() = 'authenticated')


-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- 1. 테이블 확인
-- SELECT tablename FROM pg_tables WHERE tablename IN ('class_materials', 'material_shares');

-- 2. class_materials 컬럼 확인
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'class_materials';

-- 3. RLS 정책 확인
-- SELECT policyname, cmd FROM pg_policies WHERE tablename IN ('class_materials', 'material_shares');

-- ══════════════════════════════════════════════════════════════════
