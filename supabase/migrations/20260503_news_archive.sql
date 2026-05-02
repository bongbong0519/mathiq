-- 입시 인사이트 시스템 v2: news_archive 테이블
-- 작성일: 2026-05-03

CREATE TABLE IF NOT EXISTS news_archive (
  id BIGSERIAL PRIMARY KEY,

  -- 출처 정보
  source TEXT NOT NULL,
  source_detail TEXT,
  category TEXT,

  -- 콘텐츠
  title TEXT NOT NULL,
  summary TEXT,
  description TEXT,
  original_url TEXT NOT NULL,

  -- 시간
  published_at TIMESTAMPTZ NOT NULL,
  collected_at TIMESTAMPTZ DEFAULT NOW(),

  -- 분류
  urgency TEXT DEFAULT 'normal',
  tags TEXT[] DEFAULT '{}',
  target_grade TEXT[],
  target_subject TEXT[],

  -- 메타
  is_manual BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES auth.users(id),
  view_count INTEGER DEFAULT 0,
  is_published BOOLEAN DEFAULT TRUE,

  -- 중복 방지
  url_hash TEXT UNIQUE NOT NULL
);

-- 인덱스
CREATE INDEX idx_news_published_at ON news_archive(published_at DESC);
CREATE INDEX idx_news_source ON news_archive(source);
CREATE INDEX idx_news_category ON news_archive(category);
CREATE INDEX idx_news_tags ON news_archive USING GIN(tags);

-- RLS 정책
ALTER TABLE news_archive ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read published news"
  ON news_archive FOR SELECT
  USING (is_published = TRUE);

CREATE POLICY "Only admin can insert"
  ON news_archive FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
    OR
    is_manual = FALSE
  );

CREATE POLICY "Only admin can update"
  ON news_archive FOR UPDATE
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

CREATE POLICY "Only admin can delete"
  ON news_archive FOR DELETE
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- profiles.role 컬럼 추가 (없으면)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';

-- 봉쌤 admin 설정은 수동 실행:
-- UPDATE profiles SET role = 'admin' WHERE id = '[봉쌤 UUID]';
