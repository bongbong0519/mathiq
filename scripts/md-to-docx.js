#!/usr/bin/env node
/**
 * md → docx 자동 변환 도구
 * 박제(2026-05-17): 옵시디언 md(SSOT) → docx(출력물) 변환
 * LaTeX 수식 → Word OMML 수식 자동 변환 (Pandoc 기반)
 *
 * 사용법:
 *   node scripts/md-to-docx.js <파일.md>
 *   node scripts/md-to-docx.js <폴더/> --batch
 *
 * 옵션:
 *   --out <폴더>    출력 폴더 (기본: 입력 파일과 같은 폴더)
 *   --batch         폴더 내 모든 .md 파일 일괄 변환
 *
 * 예시:
 *   node scripts/md-to-docx.js "C:\수학\한글화.md"
 *   node scripts/md-to-docx.js "C:\수학\한글화\" --batch --out "C:\수학\docx\"
 *
 * 의존:
 *   Pandoc — https://pandoc.org/installing.html
 *   (설치 안 되어 있으면 이 스크립트가 설치 방법 안내)
 */

'use strict';

const fs      = require('fs');
const path    = require('path');
const { execSync, spawnSync } = require('child_process');

// ── 인자 파싱 ──────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
if (!argv.length || argv[0] === '--help') { printHelp(); process.exit(0); }

let inputPath = null;
let outDir    = null;
let batch     = false;

for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--out'   && argv[i+1]) { outDir = argv[++i]; continue; }
  if (argv[i] === '--batch')              { batch  = true;       continue; }
  if (!argv[i].startsWith('--'))          { inputPath = argv[i]; }
}

if (!inputPath) die('❌ 입력 파일(또는 폴더) 경로를 입력하세요.');

// ── Pandoc 경로 확인 (Windows PATH 미갱신 대응) ───────────────────────────
function findPandoc() {
  // 1) 현재 PATH에서 찾기
  const r = spawnSync('pandoc', ['--version'], { encoding: 'utf-8' });
  if (!r.error && r.status === 0) return 'pandoc';

  // 2) Windows 시스템/사용자 PATH 재로드 후 찾기 (설치 후 터미널 재시작 없이도 동작)
  if (process.platform === 'win32') {
    try {
      const { execSync } = require('child_process');
      const sysPath  = execSync('reg query "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment" /v PATH 2>nul', { encoding: 'utf-8' })
        .match(/PATH\s+REG_EXPAND_SZ\s+(.+)/i)?.[1]?.trim() ?? '';
      const userPath = execSync('reg query "HKCU\\Environment" /v PATH 2>nul', { encoding: 'utf-8' })
        .match(/PATH\s+REG_(?:EXPAND_)?SZ\s+(.+)/i)?.[1]?.trim() ?? '';
      const fullPath = sysPath + ';' + userPath;
      const r2 = spawnSync('pandoc', ['--version'], {
        encoding: 'utf-8',
        env: { ...process.env, PATH: fullPath },
      });
      if (!r2.error && r2.status === 0) {
        process.env.PATH = fullPath;  // 이후 호출에도 적용
        return 'pandoc';
      }
    } catch (_) {}
  }

  return null;
}

let PANDOC_CMD = 'pandoc';

function checkPandoc() {
  const found = findPandoc();
  if (!found) {
    console.error(`
❌ Pandoc이 설치되어 있지 않습니다.

Pandoc은 md → docx 변환 (LaTeX → Word 수식 OMML)에 필요합니다.

설치 방법 (Windows):

  방법 1 — 공식 인스톨러 (권장):
    https://github.com/jgm/pandoc/releases
    → pandoc-X.X.X-windows-x86_64.msi 다운로드 후 실행

  방법 2 — winget (Windows 패키지 관리자):
    winget install JohnMacFarlane.Pandoc

  방법 3 — Chocolatey:
    choco install pandoc

설치 후 터미널 재시작 → 다시 명령어 실행
`);
    process.exit(1);
  }
  const ver = spawnSync('pandoc', ['--version'], { encoding: 'utf-8', env: process.env });
  console.log(`✅ Pandoc 감지: ${ver.stdout.split('\n')[0]}`);
}

// ── 단일 파일 변환 ────────────────────────────────────────────────────────
function convertFile(mdPath, targetDir) {
  if (!fs.existsSync(mdPath)) die(`❌ 파일 없음: ${mdPath}`);
  if (path.extname(mdPath).toLowerCase() !== '.md') {
    console.warn(`⚠️  .md 파일이 아닙니다, 스킵: ${mdPath}`);
    return false;
  }

  const baseName  = path.basename(mdPath, '.md');
  const resolvedDir = targetDir
    ? (fs.mkdirSync(targetDir, { recursive: true }), targetDir)
    : path.dirname(path.resolve(mdPath));
  const docxPath = path.join(resolvedDir, `${baseName}.docx`);

  console.log(`\n📄 변환 중: ${path.basename(mdPath)}`);
  console.log(`   → ${docxPath}`);

  // Pandoc 실행
  // docx 출력 시 LaTeX 수식($...$, $$...$$)은 Pandoc이 자동으로 OMML로 변환
  const result = spawnSync('pandoc', [
    mdPath,
    '-o', docxPath,
    '--from', 'markdown+tex_math_dollars',   // $...$ 수식 인식
    '--to', 'docx',
    '--standalone',
  ], { encoding: 'utf-8', env: process.env });

  if (result.error || result.status !== 0) {
    console.error(`❌ 변환 실패: ${result.stderr || result.error?.message || '알 수 없는 오류'}`);
    return false;
  }

  const sizeKB = (fs.statSync(docxPath).size / 1024).toFixed(1);
  console.log(`   ✅ 완료 (${sizeKB} KB)`);
  return true;
}

// ── 폴더 일괄 변환 ────────────────────────────────────────────────────────
function convertBatch(folderPath, targetDir) {
  if (!fs.existsSync(folderPath)) die(`❌ 폴더 없음: ${folderPath}`);

  const mdFiles = fs.readdirSync(folderPath)
    .filter(f => f.toLowerCase().endsWith('.md'))
    .map(f => path.join(folderPath, f));

  if (!mdFiles.length) {
    console.log('⚠️  변환할 .md 파일이 없습니다.');
    return;
  }

  console.log(`\n📁 일괄 변환: ${mdFiles.length}개 파일`);
  let ok = 0, fail = 0;

  for (const f of mdFiles) {
    const success = convertFile(f, targetDir);
    success ? ok++ : fail++;
  }

  console.log(`\n📊 결과: 성공 ${ok} / 실패 ${fail} / 합계 ${mdFiles.length}`);
}

// ── 메인 ──────────────────────────────────────────────────────────────────
console.log('\n📝 md → docx 변환 도구 (Pandoc)\n');
checkPandoc();

const resolved = path.resolve(inputPath);
const stat = fs.existsSync(resolved) ? fs.statSync(resolved) : null;

if (batch || (stat && stat.isDirectory())) {
  convertBatch(resolved, outDir);
} else {
  convertFile(resolved, outDir);
}

console.log('\n✅ 완료\n');

// ── 유틸 ──────────────────────────────────────────────────────────────────
function die(msg) { console.error(msg); process.exit(1); }

function printHelp() {
  console.log(`
md → docx 자동 변환 도구
박제(2026-05-17): 옵시디언 md(SSOT) → docx(출력물)
LaTeX 수식 → Word OMML 자동 변환

사용법:
  node scripts/md-to-docx.js <파일.md>
  node scripts/md-to-docx.js <폴더/> --batch

옵션:
  --out <폴더>    출력 폴더 (기본: 입력과 같은 폴더)
  --batch         폴더 내 .md 전체 변환

예시:
  node scripts/md-to-docx.js "C:\\수학\\한글화.md"
  node scripts/md-to-docx.js "C:\\수학\\한글화\\" --batch --out "C:\\수학\\docx\\"

의존: Pandoc (https://pandoc.org/installing.html)
`);
}
