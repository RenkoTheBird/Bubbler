import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  site: 'https://www.wubbler.xyz',
  trailingSlash: 'never',
  build: {
    format: 'file',
  },
});
