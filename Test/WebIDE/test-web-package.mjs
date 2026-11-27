import {existsSync} from 'node:fs';

// CI runs this case against both native export and older tagged releases.
if (existsSync('src/WebPackage/Archive.ts')) {
  await import('./legacy-web-package.mjs');
} else {
  await import('./native-web-package.mjs');
}
