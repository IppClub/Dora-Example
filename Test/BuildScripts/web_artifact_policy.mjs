// These exact NUL-terminated strings are Godot's in-memory Web filesystem
// roots (platform/web/os_web.cpp), not paths on the compilation machine.
// Nested files, other usernames and occurrences outside the Godot module
// remain subject to the ordinary path-leak check.
export function hasHostBuildPaths(contents, relativeFile) {
  if (relativeFile.replaceAll('\\', '/') === 'godot/dora-godot.wasm') {
    contents = contents.replace(/(^|\0)\/home\/web_user\/(?:\.config|\.cache|\.local\/share)(?=\0)/g, '$1<godot-virtual-fs>');
  }
  return /(?:\/Users\/[A-Za-z0-9._-]+\/|\/home\/[A-Za-z0-9._-]+\/|[A-Za-z]:\\(?:Users|src|work)\\)/.test(contents);
}

export function hasCredentialMaterial(contents, relativeFile) {
  if (relativeFile.replaceAll('\\', '/') === 'godot/dora-godot.wasm') {
    // Mbed TLS pk_internal.h/pkwrite.c contain these parser/writer labels.
    // Only separate labels ending immediately in NUL may be ignored. A PEM
    // header followed by key data, and all API token patterns, still fail.
    contents = contents.replace(/(^|\0)-----BEGIN (?:RSA |EC )?PRIVATE KEY-----(?:\r?\n)?(?=\0)/g, '$1<mbedtls-pem-label>');
  }
  return /(?:-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{30,})/.test(contents);
}
