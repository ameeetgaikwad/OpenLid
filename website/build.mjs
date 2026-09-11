import { mkdir, copyFile } from 'node:fs/promises';
import { build } from 'esbuild';

await mkdir('dist', { recursive: true });
for (const file of ['index.html', 'app.js', 'style.css', 'favicon.svg', 'wallpaper.png']) {
  await copyFile(file, `dist/${file}`);
}
await build({
  entryPoints: ['analytics-entry.js'],
  outfile: 'dist/analytics.js',
  bundle: true,
  minify: true,
  platform: 'browser',
  define: { 'process.env.NODE_ENV': '"production"' },
});
