#!/usr/bin/env node
/**
 * Mathpix PDF → Markdown/LaTeX 변환 도구 (시드 단계 스크립트)
 * 박제(2026-05-15) C안: Mathpix Convert API 시드 도구
 *
 * 사용법:
 *   node scripts/mathpix-pdf-convert.js <PDF_경로> [옵션]
 *
 * 옵션:
 *   --format mmd|tex|md   출력 형식 (기본: mmd = Mathpix Markdown)
 *   --out <디렉토리>       출력 파일 저장 위치 (기본: PDF와 같은 위치)
 *
 * 예시:
 *   node scripts/mathpix-pdf-convert.js "시험지.pdf"
 *   node scripts/mathpix-pdf-convert.js "해설.pdf" --format tex --out output/
 *
 * .env 파일에 다음 설정 필요:
 *   MATHPIX_APP_ID=your_app_id
 *   MATHPIX_APP_KEY=your_app_key
 *
 * 비용: 페이지당 $0.0035 (파이캐쉬 차감)
 */

'use strict';
require('dotenv').config();
const fs   = require('fs');
const path = require('path');

const BASE_URL = 'https://api.mathpix.com';
const APP_ID   = process.env.MATHPIX_APP_ID;
const APP_KEY  = process.env.MATHPIX_APP_KEY;

// ── 인자 파싱 ──────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
if (!args.length || args[0] === '--help') { printHelp(); process.exit(0); }

const pdfPath = args[0];
let format = 'mmd';
let outDir  = null;

for (let i = 1; i < args.length; i++) {
  if (args[i] === '--format' && args[i + 1]) format = args[++i];
  if (args[i] === '--out'    && args[i + 1]) outDir  = args[++i];
}

if (!['mmd', 'tex', 'md', 'docx', 'html'].includes(format)) {
  die(`❌ 지원하지 않는 형식: ${format}. mmd / md / tex / docx / html 중 선택`);
}

// Mathpix API 포맷 키 매핑 (mmd → md, tex → tex.zip)
const API_FORMAT_MAP = { mmd: 'md', tex: 'tex.zip', md: 'md', docx: 'docx', html: 'html' };
const EXT_MAP        = { mmd: 'mmd', tex: 'zip', md: 'md', docx: 'docx', html: 'html' };
const apiFormat = API_FORMAT_MAP[format];
const outExt    = EXT_MAP[format];

// ── 환경 검증 ──────────────────────────────────────────────────────────────
if (!APP_ID || !APP_KEY) {
  die('❌ .env에 MATHPIX_APP_ID, MATHPIX_APP_KEY 가 없습니다.\n   console.mathpix.com → Applications → 발급 후 .env에 입력하세요.');
}
if (!fs.existsSync(pdfPath)) die(`❌ 파일 없음: ${pdfPath}`);
if (path.extname(pdfPath).toLowerCase() !== '.pdf') die(`❌ PDF 파일만 지원합니다: ${pdfPath}`);

// ── 출력 경로 결정 ────────────────────────────────────────────────────────
const baseName  = path.basename(pdfPath, '.pdf');
const targetDir = outDir
  ? (fs.mkdirSync(outDir, { recursive: true }), outDir)
  : path.dirname(path.resolve(pdfPath));
const outPath = path.join(targetDir, `${baseName}.${outExt}`);

// ── 공통 헤더 ─────────────────────────────────────────────────────────────
const AUTH_HEADERS = { app_id: APP_ID, app_key: APP_KEY };

// ── 메인 ──────────────────────────────────────────────────────────────────
console.log(`\n📄 Mathpix PDF 변환 시작`);
console.log(`   입력: ${path.resolve(pdfPath)}`);
console.log(`   형식: ${format}`);
console.log(`   출력: ${outPath}\n`);

(async () => {
  try {
    const pdfId    = await uploadPdf(pdfPath);
    console.log(`✅ 업로드 완료. pdf_id: ${pdfId}`);

    const result   = await pollUntilDone(pdfId);
    const pages    = result.num_pages ?? '?';
    console.log(`✅ 처리 완료. 페이지 수: ${pages}`);

    console.log(`\n📥 결과 다운로드 중...`);
    const content  = await downloadResult(pdfId, apiFormat);

    fs.writeFileSync(outPath, content, 'utf-8');
    const sizeKB   = (fs.statSync(outPath).size / 1024).toFixed(1);

    console.log(`\n✅ 저장 완료: ${outPath}`);
    console.log(`   파일 크기: ${sizeKB} KB`);
    if (pages !== '?') {
      const cost = (pages * 0.0035).toFixed(4);
      console.log(`   예상 비용: $${cost} (${pages}페이지 × $0.0035)`);
    }
    console.log();
  } catch (err) {
    die(`❌ 오류: ${err.message}`);
  }
})();

// ── 함수 ──────────────────────────────────────────────────────────────────

async function uploadPdf(pdfPath) {
  console.log(`📤 PDF 업로드 중...`);

  const fileBuffer = fs.readFileSync(pdfPath);
  const boundary   = `----MathpixBoundary${Date.now()}`;

  // multipart/form-data 수동 구성 (Node 24 FormData는 Buffer를 Blob으로 못 받는 경우 대비)
  const optionsJson = JSON.stringify({
    conversion_formats: { [apiFormat]: true },
    math_inline_delimiters:  ['$', '$'],
    math_display_delimiters: ['$$', '$$'],
    enable_tables_fallback:  true,
    // 2단 레이아웃 대응 (시험지 column 구조)
    rm_spaces: true,
    rm_fonts:  true,
  });

  const CRLF      = '\r\n';
  const filename  = path.basename(pdfPath);
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

  const res  = await fetch(`${BASE_URL}/v3/pdf`, {
    method:  'POST',
    headers: {
      ...AUTH_HEADERS,
      'Content-Type':   `multipart/form-data; boundary=${boundary}`,
      'Content-Length': String(bodyBuf.length),
    },
    body: bodyBuf,
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = data.error || data.message || JSON.stringify(data);
    if (res.status === 401) throw new Error(`API 인증 실패. APP_ID/APP_KEY 확인 필요.\n   ${msg}`);
    if (res.status === 429) throw new Error(`요청 한도 초과. 잠시 후 재시도.\n   ${msg}`);
    throw new Error(`업로드 실패 (${res.status}): ${msg}`);
  }
  if (!data.pdf_id) throw new Error(`pdf_id 없음: ${JSON.stringify(data)}`);
  return data.pdf_id;
}

async function pollUntilDone(pdfId) {
  const MAX_MS   = 5 * 60 * 1000; // 5분
  const INTERVAL = 3000;
  const start    = Date.now();
  let   lastStatus = '';

  process.stdout.write('⏳ 처리 대기 중');

  while (Date.now() - start < MAX_MS) {
    await sleep(INTERVAL);

    const res  = await fetch(`${BASE_URL}/v3/pdf/${pdfId}`, { headers: AUTH_HEADERS });
    const data = await res.json().catch(() => ({}));

    if (!res.ok) throw new Error(`상태 조회 실패 (${res.status}): ${data.error || JSON.stringify(data)}`);

    const status = data.status ?? 'unknown';
    if (status !== lastStatus) { process.stdout.write(` [${status}]`); lastStatus = status; }
    else                        { process.stdout.write('.'); }

    if (status === 'completed') { process.stdout.write('\n'); return data; }
    if (status === 'error') {
      process.stdout.write('\n');
      throw new Error(`Mathpix 처리 오류: ${data.error || JSON.stringify(data)}`);
    }
  }

  process.stdout.write('\n');
  throw new Error('처리 시간 초과 (5분). PDF가 너무 크거나 서버 문제입니다.');
}

async function downloadResult(pdfId, apiFormat) {
  const res = await fetch(`${BASE_URL}/v3/pdf/${pdfId}.${apiFormat}`, { headers: AUTH_HEADERS });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`다운로드 실패 (${res.status}): ${text.slice(0, 200)}`);
  }
  return res.text();
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
function die(msg)  { console.error(msg); process.exit(1); }

function printHelp() {
  console.log(`
Mathpix PDF → Markdown/LaTeX 변환 도구

사용법:
  node scripts/mathpix-pdf-convert.js <PDF_경로> [옵션]

옵션:
  --format mmd|tex|md   출력 형식 (기본: mmd)
  --out <디렉토리>       출력 위치 (기본: PDF와 같은 폴더)

예시:
  node scripts/mathpix-pdf-convert.js "해설.pdf"
  node scripts/mathpix-pdf-convert.js "해설.pdf" --format tex
  node scripts/mathpix-pdf-convert.js "해설.pdf" --format mmd --out output/

.env:
  MATHPIX_APP_ID=your_app_id
  MATHPIX_APP_KEY=your_app_key

비용: 페이지당 $0.0035
`);
}
