import { execFileSync } from 'node:child_process';
import { writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { dirname, resolve, join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const outputDirectory = dirname(fileURLToPath(import.meta.url));
const repository = resolve(outputDirectory, '../reference-web');
const git = (args) => execFileSync('git', args, { cwd: repository, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'] });
const baseline = git(['rev-parse', 'HEAD']).trim();
if (baseline !== '3c24df131699c71fac4e500f0e1c531eeab519d2') throw new Error('Unexpected reference source revision');
const paths = [
  'package.json', 'package-lock.json', 'server', 'database',
  'backend/index.mjs', 'backend/gateway.test.mjs', 'backend/package.json', 'backend/package-lock.json',
  'client/package.json', 'client/package-lock.json', 'client/src/test/dependency-compatibility.test.tsx',
  'client/src/components/TotalDataForm.tsx', 'client/src/pages/BackendThreeLogins.tsx',
  'client/src/pages/ReportsPage.tsx', 'client/src/services/api.ts'
];
let patch = git(['diff', '--binary', '--no-ext-diff', '--', ...paths]);
const added = git(['ls-files', '--others', '--exclude-standard', '--', ...paths]).split(/\r?\n/).filter(Boolean);
for (const file of added) {
  try {
    patch += git(['diff', '--no-index', '--', process.platform === 'win32' ? 'NUL' : '/dev/null', file]);
  } catch (error) {
    if (error.status !== 1 || !error.stdout) throw error;
    patch += error.stdout;
  }
}
const output = resolve(outputDirectory, 'ventureplus-authorization.patch');
writeFileSync(output, patch, 'utf8');
git(['apply', '--reverse', '--check', output]);
const temporaryRoot = resolve(tmpdir());
const verification = mkdtempSync(join(temporaryRoot, 'ventureplus-backend-patch-'));
try {
  const archivePath = join(verification, 'baseline.tar');
  execFileSync('git', ['archive', '--format=tar', '--output', archivePath, 'HEAD', 'package.json', 'package-lock.json', 'server', 'database', 'backend', 'client'], { cwd: repository });
  execFileSync('tar', ['-xf', archivePath, '-C', verification]);
  execFileSync('git', ['apply', '--check', output], { cwd: verification });
} finally {
  // Delete only the exact disposable directory created above, inside the temp root.
  if (dirname(resolve(verification)) !== temporaryRoot) throw new Error('Unexpected verification path');
  rmSync(verification, { recursive: true, force: true });
}
console.log(`Exported ${output} (${Buffer.byteLength(patch)} bytes); reverse check and clean-baseline apply check passed.`);
