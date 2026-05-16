#!/usr/bin/env node
/**
 * 시드 자동 한글화 도구
 * 박제(2026-05-17) 봉쌤 워크플로우: 명령줄 1줄 → 옵시디언 md 파일
 *
 * 사용법:
 *   node scripts/auto-translate-exam.js <문제.pdf> [해설.pdf] [옵션]
 *
 * 옵션:
 *   --out <경로.md>       출력 md 파일 경로 (기본: 문제 PDF와 같은 폴더)
 *   --model <모델>        opus(기본) / sonnet / haiku / 또는 full model ID
 *   --skip-mathpix        Mathpix 스킵 (mmd 파일이 이미 있으면 재사용)
 *   --exam-name <이름>    시험명 (기본: PDF 파일명에서 추출)
 *
 * 예시:
 *   node scripts/auto-translate-exam.js "문제.pdf" "해설.pdf"
 *   node scripts/auto-translate-exam.js "문제.pdf" --skip-mathpix
 *   node scripts/auto-translate-exam.js "문제.pdf" --model sonnet
 *
 * .env 필요:
 *   MATHPIX_APP_ID, MATHPIX_APP_KEY   (Mathpix Convert API)
 *   ANTHROPIC_API_KEY                  (Claude API)
 *
 * 비용 기준 (시험지 1회당):
 *   Mathpix: ~$0.028 (~40원, 8페이지)
 *   Opus:    ~$0.10  (~150원, 기본 — 박제(2026-05-17) 봉쌤 시간 가치 우선)
 *   Sonnet:  ~$0.04  (~60원,  --model sonnet)
 *   Haiku:   ~$0.02  (~25원,  --model haiku)
 */

'use strict';
require('dotenv').config();

const fs   = require('fs');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk');

// ── 상수 ──────────────────────────────────────────────────────────────────
const MATHPIX_BASE  = 'https://api.mathpix.com';
const MATHPIX_ID    = process.env.MATHPIX_APP_ID;
const MATHPIX_KEY   = process.env.MATHPIX_APP_KEY;
const ANTHROPIC_KEY = process.env.ANTHROPIC_API_KEY;

const DEFAULT_MODEL = 'claude-opus-4-7';

// ── 인자 파싱 ──────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
if (!argv.length || argv[0] === '--help') { printHelp(); process.exit(0); }

let mondaePdf  = null;
let haesulPdf  = null;
let outPath    = null;
let modelId    = DEFAULT_MODEL;
let skipMathpix = false;
let examName   = null;

for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--out'    && argv[i+1]) { outPath    = argv[++i]; continue; }
  if (a === '--model'  && argv[i+1]) { modelId    = resolveModel(argv[++i]); continue; }
  if (a === '--exam-name' && argv[i+1]) { examName = argv[++i]; continue; }
  if (a === '--skip-mathpix') { skipMathpix = true; continue; }
  if (!a.startsWith('--')) {
    if (!mondaePdf)      mondaePdf  = a;
    else if (!haesulPdf) haesulPdf  = a;
  }
}

if (!mondaePdf) die('❌ 문제 PDF 경로를 입력하세요.');

// ── 경로 결정 ─────────────────────────────────────────────────────────────
const mondaeBase = path.basename(mondaePdf, '.pdf');
const mondaeDir  = path.dirname(path.resolve(mondaePdf));
const mondaeMmd  = path.join(mondaeDir, `${mondaeBase}.mmd`);
const haesulBase = haesulPdf ? path.basename(haesulPdf, '.pdf') : null;
const haesulMmd  = haesulPdf ? path.join(path.dirname(path.resolve(haesulPdf)), `${haesulBase}.mmd`) : null;

if (!outPath) {
  outPath = path.join(mondaeDir, `${mondaeBase}_한글화.md`);
}
if (!examName) {
  examName = mondaeBase.replace(/_문제$/, '').replace(/_/, ' ');
}

// ── 환경 검증 ──────────────────────────────────────────────────────────────
if (!skipMathpix && (!MATHPIX_ID || !MATHPIX_KEY)) {
  die('❌ .env에 MATHPIX_APP_ID, MATHPIX_APP_KEY 없음\n   console.mathpix.com → Applications에서 발급');
}
if (!ANTHROPIC_KEY) {
  die('❌ .env에 ANTHROPIC_API_KEY 없음\n   console.anthropic.com → API Keys에서 발급 후 .env에 ANTHROPIC_API_KEY=sk-ant-... 추가');
}

const anthropic = new Anthropic({ apiKey: ANTHROPIC_KEY });

// ── 메인 ──────────────────────────────────────────────────────────────────
console.log('\n🚀 시드 자동 한글화 도구');
console.log(`   문제 PDF: ${path.resolve(mondaePdf)}`);
if (haesulPdf) console.log(`   해설 PDF: ${path.resolve(haesulPdf)}`);
console.log(`   Claude 모델: ${modelId}`);
console.log(`   출력: ${outPath}\n`);

(async () => {
  try {
    // ── Step 1: Mathpix PDF → mmd ────────────────────────────────────────
    let mondaeMmdText, haesulMmdText = null;

    if (skipMathpix && fs.existsSync(mondaeMmd)) {
      console.log(`♻️  문제 mmd 재사용: ${mondaeMmd}`);
      mondaeMmdText = fs.readFileSync(mondaeMmd, 'utf-8');
    } else {
      if (!fs.existsSync(mondaePdf)) die(`❌ 파일 없음: ${mondaePdf}`);
      mondaeMmdText = await pdfToMmd(mondaePdf, mondaeMmd);
    }

    if (haesulPdf) {
      if (skipMathpix && haesulMmd && fs.existsSync(haesulMmd)) {
        console.log(`♻️  해설 mmd 재사용: ${haesulMmd}`);
        haesulMmdText = fs.readFileSync(haesulMmd, 'utf-8');
      } else {
        if (!fs.existsSync(haesulPdf)) die(`❌ 파일 없음: ${haesulPdf}`);
        haesulMmdText = await pdfToMmd(haesulPdf, haesulMmd);
      }
    }

    // ── Step 2: Claude API → 한글화 + 분류 + 5역량 ───────────────────────
    console.log(`\n🤖 Claude 호출 중... (${modelId})`);
    const questions = await translateExam(mondaeMmdText, haesulMmdText, examName);
    console.log(`✅ ${questions.length}문제 처리 완료`);

    // ── Step 3: JSON → md 파일 생성 ───────────────────────────────────────
    const mdContent = buildMd(examName, questions);
    fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
    fs.writeFileSync(outPath, mdContent, 'utf-8');

    const sizeKB = (fs.statSync(outPath).size / 1024).toFixed(1);
    console.log(`\n✅ 저장 완료: ${outPath}`);
    console.log(`   파일 크기: ${sizeKB} KB`);
    console.log(`   문제 수: ${questions.length}`);
    console.log('\n📋 다음 단계: 옵시디언에서 파일 열어서 봉쌤 검토 + 미세 수정\n');

  } catch (err) {
    die(`❌ 오류: ${err.message}`);
  }
})();

// ── Mathpix: PDF → mmd ────────────────────────────────────────────────────
async function pdfToMmd(pdfPath, savePath) {
  console.log(`📤 Mathpix 업로드 중: ${path.basename(pdfPath)}`);

  const fileBuffer = fs.readFileSync(pdfPath);
  const boundary   = `----MathpixBoundary${Date.now()}`;
  const optionsJson = JSON.stringify({
    conversion_formats: { md: true },
    math_inline_delimiters:  ['$', '$'],
    math_display_delimiters: ['$$', '$$'],
    enable_tables_fallback:  true,
    rm_spaces: true,
    rm_fonts:  true,
  });

  const CRLF = '\r\n';
  const filename = path.basename(pdfPath);
  const bodyParts = [
    `--${boundary}${CRLF}`,
    `Content-Disposition: form-data; name="options_json"${CRLF}${CRLF}`,
    optionsJson, CRLF,
    `--${boundary}${CRLF}`,
    `Content-Disposition: form-data; name="file"; filename="${filename}"${CRLF}`,
    `Content-Type: application/pdf${CRLF}${CRLF}`,
  ];
  const prefixBuf = Buffer.from(bodyParts.join(''), 'utf-8');
  const suffixBuf = Buffer.from(`${CRLF}--${boundary}--${CRLF}`, 'utf-8');
  const bodyBuf   = Buffer.concat([prefixBuf, fileBuffer, suffixBuf]);

  const authHeaders = { app_id: MATHPIX_ID, app_key: MATHPIX_KEY };

  const res  = await fetch(`${MATHPIX_BASE}/v3/pdf`, {
    method: 'POST',
    headers: {
      ...authHeaders,
      'Content-Type':   `multipart/form-data; boundary=${boundary}`,
      'Content-Length': String(bodyBuf.length),
    },
    body: bodyBuf,
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = data.error || data.message || JSON.stringify(data);
    if (res.status === 401) throw new Error(`Mathpix API 인증 실패: ${msg}`);
    throw new Error(`Mathpix 업로드 실패 (${res.status}): ${msg}`);
  }
  if (!data.pdf_id) throw new Error(`pdf_id 없음: ${JSON.stringify(data)}`);

  const pdfId = data.pdf_id;
  console.log(`✅ 업로드 완료 (pdf_id: ${pdfId})`);

  // 폴링
  const MAX_MS = 5 * 60 * 1000;
  const start  = Date.now();
  process.stdout.write('⏳ 처리 대기 중');
  let lastStatus = '';

  while (Date.now() - start < MAX_MS) {
    await sleep(3000);
    const r    = await fetch(`${MATHPIX_BASE}/v3/pdf/${pdfId}`, { headers: authHeaders });
    const d    = await r.json().catch(() => ({}));
    const status = d.status ?? 'unknown';
    if (status !== lastStatus) { process.stdout.write(` [${status}]`); lastStatus = status; }
    else                        { process.stdout.write('.'); }
    if (status === 'completed') {
      const pages = d.num_pages ?? '?';
      process.stdout.write('\n');
      console.log(`✅ 처리 완료 (${pages}페이지, 예상 비용: $${pages !== '?' ? (pages * 0.0035).toFixed(4) : '?'})`);
      break;
    }
    if (status === 'error') {
      process.stdout.write('\n');
      throw new Error(`Mathpix 처리 오류: ${d.error || JSON.stringify(d)}`);
    }
  }

  // 다운로드
  const dlRes = await fetch(`${MATHPIX_BASE}/v3/pdf/${pdfId}.md`, { headers: authHeaders });
  if (!dlRes.ok) {
    const t = await dlRes.text().catch(() => '');
    throw new Error(`다운로드 실패 (${dlRes.status}): ${t.slice(0, 200)}`);
  }
  const mmdText = await dlRes.text();
  if (savePath) fs.writeFileSync(savePath, mmdText, 'utf-8');
  console.log(`💾 mmd 저장: ${savePath}`);

  return mmdText;
}

// ── Claude API: 한글화 + 분류 + 5역량 ────────────────────────────────────
async function translateExam(mondaeMmd, haesulMmd, examName) {
  const haesulSection = haesulMmd
    ? `\n\n=== 해설 mmd ===\n${haesulMmd}`
    : '\n\n[해설 PDF 미제공 — 해설 필드는 빈칸으로 남길 것]';

  const systemPrompt = `당신은 한국 수학 교육 전문가입니다.
박제(2026-05-07) 봉쌤 수학관: 폴리아 계보, 이해 기반, 학생이 스스로 생각하도록 유도.
박제(2026-05-14) 5역량: 문제해결(어떻게 풀지 계획), 추론(논리적 근거), 의사소통(표현/기호 이해), 연결(개념간 연결), 정보처리(주어진 정보 활용).`;

  const userPrompt = `다음은 "${examName}" 시험지의 Mathpix Markdown 변환 결과입니다.
수식은 LaTeX($...$, $$...$$)로 표현되어 있습니다.

=== 문제 mmd ===${mondaeMmd}${haesulSection}

---

위 내용을 분석하여 **모든 문제**를 추출하고 아래 JSON 형식으로 응답하세요.

주의사항:
- 2단 컬럼 PDF 특성상 문제 번호 순서가 뒤바뀔 수 있음 → 반드시 번호 순 정렬(1, 2, 3, ...)
- 같은 번호가 두 번 나타나면 문맥으로 올바른 것 선택
- 한글화: LaTeX 수식을 자연스러운 한국어 수학 표현으로 변환
  예: $\\sqrt{3}$ → "루트 3" 또는 "√3", $\\frac{a}{b}$ → "a분의 b", $x^2$ → "x의 제곱"
  단, 복잡한 수식은 풀어쓰되 의미가 명확하게
- 해설이 제공된 경우: 해설도 한국어로 요약 (수식 포함)
- 해설 없는 경우: haesul 필드 = ""
- 분류.단원: 가능한 한 구체적으로 (예: "일차방정식", "이차함수", "집합", "평면기하")
- 난이도: 1=매우쉬움, 5=보통, 9=매우어려움 (고1 3월 기준)
- 5역량: 해당 문제에서 주로 요구되는 역량에만 점수 부여 (나머지 0)

응답 형식 (JSON만, 설명 없이):
[
  {
    "num": 1,
    "score": 2,
    "type": "선택형",
    "원문": "원문 LaTeX 텍스트 그대로",
    "한글화": "자연스러운 한국어 설명",
    "haesul": "해설 한국어 요약 (없으면 빈 문자열)",
    "분류": {
      "단원": "단원명",
      "유형": "문제 유형",
      "난이도": 3
    },
    "역량": {
      "문제해결": 2,
      "추론": 1,
      "의사소통": 0,
      "연결": 1,
      "정보처리": 0
    }
  }
]`;

  const response = await anthropic.messages.create({
    model: modelId,
    max_tokens: 16000,
    messages: [
      { role: 'user', content: userPrompt }
    ],
    system: systemPrompt,
  });

  // 비용 추정 로그
  const usage = response.usage;
  const pricing = modelId.includes('haiku')
    ? { in: 0.80,  out: 4.0 }
    : modelId.includes('sonnet')
    ? { in: 3.0,   out: 15.0 }
    : { in: 15.0,  out: 75.0 };  // opus
  const cost = ((usage.input_tokens * pricing.in + usage.output_tokens * pricing.out) / 1_000_000).toFixed(4);
  console.log(`   토큰: 입력 ${usage.input_tokens}, 출력 ${usage.output_tokens}, 예상 비용 $${cost}`);

  // JSON 파싱
  const raw = response.content[0].text.trim();
  const jsonMatch = raw.match(/\[[\s\S]*\]/);
  if (!jsonMatch) throw new Error(`Claude 응답에서 JSON 배열을 찾을 수 없음:\n${raw.slice(0, 500)}`);

  let questions;
  try {
    questions = JSON.parse(jsonMatch[0]);
  } catch (e) {
    throw new Error(`JSON 파싱 실패: ${e.message}\n응답 일부: ${raw.slice(0, 300)}`);
  }

  if (!Array.isArray(questions) || questions.length === 0) {
    throw new Error(`문제 배열 비어있음. 응답: ${raw.slice(0, 300)}`);
  }

  // 번호 순 정렬 보장
  questions.sort((a, b) => (a.num || 0) - (b.num || 0));

  return questions;
}

// ── JSON → md 파일 생성 ────────────────────────────────────────────────────
function buildMd(examName, questions) {
  const now = new Date().toISOString().slice(0, 10);
  const lines = [
    `# ${examName}`,
    ``,
    `> AI 자동 한글화 (${now}) — 봉쌤 검토 대기`,
    `> 모델: ${modelId}`,
    `> 문제 수: ${questions.length}`,
    ``,
  ];

  for (const q of questions) {
    const section = q.type || (q.num <= 21 ? '선택형' : '단답형');
    lines.push(`## 문제 ${q.num}  [${q.score ?? '?'}점]  (${section})`);
    lines.push(``);

    lines.push(`### 원문 LaTeX`);
    lines.push(``);
    lines.push(q.원문 || '');
    lines.push(``);

    lines.push(`### 한글화 (AI 생성, 봉쌤 검토 대기)`);
    lines.push(``);
    lines.push(q.한글화 || '');
    lines.push(``);

    lines.push(`### 해설 (AI 생성, 봉쌤 검토 대기)`);
    lines.push(``);
    lines.push(q.haesul || '_(해설 PDF 미제공)_');
    lines.push(``);

    lines.push(`### 분류`);
    lines.push(``);
    const c = q.분류 || {};
    lines.push(`- 단원: ${c.단원 || ''}`);
    lines.push(`- 유형: ${c.유형 || ''}`);
    lines.push(`- 난이도 (1~9): ${c.난이도 ?? ''}`);
    lines.push(``);

    lines.push(`### 5역량 (0~3)`);
    lines.push(``);
    const r = q.역량 || {};
    lines.push(`- 문제해결: ${r.문제해결 ?? ''}`);
    lines.push(`- 추론: ${r.추론 ?? ''}`);
    lines.push(`- 의사소통: ${r.의사소통 ?? ''}`);
    lines.push(`- 연결: ${r.연결 ?? ''}`);
    lines.push(`- 정보처리: ${r.정보처리 ?? ''}`);
    lines.push(``);

    lines.push(`---`);
    lines.push(``);
  }

  return lines.join('\n');
}

// ── 유틸 ──────────────────────────────────────────────────────────────────
function resolveModel(alias) {
  const map = {
    opus:   'claude-opus-4-7',
    sonnet: 'claude-sonnet-4-6',
    haiku:  'claude-haiku-4-5-20251001',
  };
  return map[alias.toLowerCase()] ?? alias;
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
function die(msg)  { console.error(msg); process.exit(1); }

function printHelp() {
  console.log(`
시드 자동 한글화 도구
박제(2026-05-17): PDF → 한글화 + 분류 + 5역량 → md 파일

사용법:
  node scripts/auto-translate-exam.js <문제.pdf> [해설.pdf] [옵션]

옵션:
  --out <경로.md>       출력 파일 경로 (기본: 문제 PDF 폴더)
  --model <모델>        Claude 모델: opus(기본) / sonnet / haiku / 또는 full model ID
  --skip-mathpix        mmd 파일 재사용 (이미 변환된 경우)
  --exam-name <이름>    시험명 (기본: PDF 파일명)

예시:
  node scripts/auto-translate-exam.js "C:\\수학\\2006년 고1 3월_문제.pdf"
  node scripts/auto-translate-exam.js "문제.pdf" "해설.pdf" --out "output.md"
  node scripts/auto-translate-exam.js "문제.pdf" --skip-mathpix  # mmd 재사용

비용 (시험지 1회당):
  Mathpix: ~$0.028  (8페이지, ~40원)
  Opus:    ~$0.10   (~150원, 기본)
  Sonnet:  ~$0.04   (~60원,  --model sonnet)
  Haiku:   ~$0.02   (~25원,  --model haiku)

.env 필요:
  MATHPIX_APP_ID=...
  MATHPIX_APP_KEY=...
  ANTHROPIC_API_KEY=sk-ant-...
`);
}
