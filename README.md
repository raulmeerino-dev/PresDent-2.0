# PresDent 2.0

Aplicación Flutter para gestión de presupuestos odontológicos con dictado por voz, parser 100% local y exportación PDF.

## CI/CD con Codemagic

El proyecto ya incluye `codemagic.yaml` con dos workflows:

- `android-release`: genera APK (`split-per-abi`) y AAB, con firma release si hay secretos.
- `ios-unsigned-ipa`: genera IPA sin firma (útil para pruebas/distribución manual).

### Secrets requeridos (grupo `secret` en Codemagic)

#### Android signing (recomendado para release)

- `CM_KEYSTORE` (keystore en base64)
- `CM_KEY_ALIAS`
- `CM_KEYSTORE_PASSWORD`
- `CM_KEY_PASSWORD`

Si estos cuatro no están, el build Android usa fallback con debug signing.

### Parser local

El parseo de transcripciones está configurado para ejecutarse siempre en local.
No se requieren variables de entorno ni endpoints externos para interpretar texto.

### Versionado de releases

Se controla desde `pubspec.yaml` con `version: x.y.z+build`.

- `1.0.0+1` → release `PresDent 2.0 1.0`
- `1.0.1+2` → hotfix `PresDent 2.0 1.0.1`
- `1.1.0+3` → minor `PresDent 2.0 1.1`

Para publicar una nueva versión, incrementa `version` en `pubspec.yaml` y dispara el workflow correspondiente en Codemagic.
