# Android build container

A persistent Docker container that matches CI (`.github/workflows/build.yml`):
Flutter 3.47.2, JDK 21, Android SDK 36, NDK 28.2.13676358.
iOS builds still need macOS/Xcode.

## Start (once)

```sh
docker compose -f docker/compose.yaml up -d --build
```

The container keeps running (`restart: unless-stopped`). Pub and Gradle caches
live in named volumes, so builds after the first one are much faster.

## Build

```sh
docker exec safecall-flutter flutter pub get
docker exec safecall-flutter flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk (on the host)
```

Or open a shell: `docker exec -it safecall-flutter bash`.

## Firebase config

`google-services.json` is mounted read-only from
`lyn_lab/SafeCall_creds/main_app_creds/google-services.json` (a sibling of the `SafeCall/` repo folder).
Point it elsewhere with `GOOGLE_SERVICES_JSON=/abs/path docker compose -f docker/compose.yaml up -d`.

## Notes

- Runs as `linux/amd64` (Android build-tools are x86_64-only), emulated via
  Rosetta on Apple Silicon — enable "Use Rosetta for x86/amd64 emulation" in
  Docker Desktop for speed.
- Memory: `docker/gradle.properties` caps Gradle for the container. If builds
  die with "Gradle build daemon disappeared", raise Docker Desktop's memory
  limit (Settings → Resources), 12 GB+ recommended.
- After editing `docker/gradle.properties`, run
  `docker compose -f docker/compose.yaml up -d --force-recreate` (single-file
  mounts don't pick up editors that replace the file).
- Release signing: put `android/key.properties` and the keystore in the repo
  as usual; without them the release APK is debug-signed.
- Stop / remove: `docker compose -f docker/compose.yaml down`
  (add `-v` to also delete the caches).
