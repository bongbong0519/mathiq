-- ══════════════════════════════════════
--  materials 테이블 (자료실)
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.materials (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  school_level TEXT NOT NULL CHECK (school_level IN ('elementary', 'middle', 'high')),
  grade INT,
  semester INT CHECK (semester IN (1, 2)),
  area TEXT,
  unit TEXT,
  file_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size BIGINT,
  uploader_id UUID NOT NULL REFERENCES auth.users(id),
  uploader_name TEXT,
  download_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.materials IS '자료실 - 학습 자료 공유';
COMMENT ON COLUMN public.materials.school_level IS 'elementary=초, middle=중, high=고';
COMMENT ON COLUMN public.materials.grade IS '학년 (1~6 또는 1~3)';
COMMENT ON COLUMN public.materials.semester IS '학기 (1 또는 2)';
COMMENT ON COLUMN public.materials.area IS '영역 (예: 수와 연산, 도형, 측정 등)';
COMMENT ON COLUMN public.materials.unit IS '단원명';

CREATE INDEX IF NOT EXISTS idx_materials_school_level ON public.materials(school_level);
CREATE INDEX IF NOT EXISTS idx_materials_grade ON public.materials(grade);
CREATE INDEX IF NOT EXISTS idx_materials_created_at ON public.materials(created_at DESC);

-- ══════════════════════════════════════
--  RLS 정책
-- ══════════════════════════════════════

ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;

-- 읽기: 로그인한 모든 사용자
CREATE POLICY "materials_select"
  ON public.materials FOR SELECT
  TO authenticated
  USING (true);

-- 업로드: teacher, director, admin만
CREATE POLICY "materials_insert"
  ON public.materials FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('teacher', 'director', 'admin')
        AND profiles.status = 'approved'
    )
  );

-- 수정: 본인 또는 admin
CREATE POLICY "materials_update"
  ON public.materials FOR UPDATE
  TO authenticated
  USING (
    uploader_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- 삭제: 본인 또는 admin
CREATE POLICY "materials_delete"
  ON public.materials FOR DELETE
  TO authenticated
  USING (
    uploader_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- ══════════════════════════════════════
--  Storage 버킷 생성 (Supabase Storage)
-- ══════════════════════════════════════
-- 아래는 Supabase 대시보드 > Storage에서 수동으로 생성하거나 SQL로:

INSERT INTO storage.buckets (id, name, public)
VALUES ('materials', 'materials', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: 누구나 읽기, 인증된 사용자만 업로드, 본인만 삭제
CREATE POLICY "materials_storage_read"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'materials');

CREATE POLICY "materials_storage_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'materials'
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('teacher', 'director', 'admin')
        AND profiles.status = 'approved'
    )
  );

CREATE POLICY "materials_storage_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'materials'
    AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
      )
    )
  );

-- ══════════════════════════════════════
--  RPC: 다운로드 카운트 증가
-- ══════════════════════════════════════

CREATE OR REPLACE FUNCTION public.increment_material_download(material_id UUID)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE public.materials
  SET download_count = download_count + 1
  WHERE id = material_id;
$$;
