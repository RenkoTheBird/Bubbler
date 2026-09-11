import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';

const __dirname = dirname(fileURLToPath(import.meta.url));
const LEGALDOCS_DIR = resolve(__dirname, '../../../legaldocs');

/** Strip draft editor NOTES at the top of source markdown. */
function stripDraftNotes(raw: string): string {
  return raw.replace(/^(?:--\s*NOTE:.*\n)+\s*/m, '').trimStart();
}

export function loadLegalMarkdown(filename: string): string {
  const raw = readFileSync(resolve(LEGALDOCS_DIR, filename), 'utf-8');
  return stripDraftNotes(raw);
}

export function renderLegalHtml(filename: string): string {
  const markdown = loadLegalMarkdown(filename);
  return marked.parse(markdown, { async: false }) as string;
}

export const LEGAL_ROUTES = {
  privacy: {
    path: '/privacy',
    title: 'Privacy Policy',
    file: 'privacy-policy.md',
  },
  terms: {
    path: '/terms',
    title: 'Terms of Service',
    file: 'terms-of-service.md',
  },
  guidelines: {
    path: '/community-guidelines',
    title: 'Community Guidelines',
    file: 'community-guidelines.md',
  },
} as const;
