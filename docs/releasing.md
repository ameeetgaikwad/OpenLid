# Repository launch and releases

Source publication and a production-ready binary release are separate milestones. The current tree is an alpha; do not imply that live hardware testing or notarization has happened.

## Before publishing the repository

- Confirm maintainer access for [ameeetgaikwad/OpenLid](https://github.com/ameeetgaikwad/OpenLid).
- Review the public file list. Keep `dist/`, `.build/`, signing credentials, `.env` files, and local `docs/builds/` session notes out of Git. Do not upload the whole workspace as a ZIP.
- Confirm the MIT license and attribution match all contributed code and assets.
- Run `bash scripts/check.sh` from a clean checkout on macOS.
- Enable GitHub private vulnerability reporting and establish a private moderation contact. Update SECURITY.md and CODE_OF_CONDUCT.md with a durable contact if needed.
- Enable issues, configure maintainer access, and protect the default branch. Require the macOS build job to pass once its first hosted run succeeds.
- Confirm issue forms and the PR template render correctly on GitHub.
- Add the repository URL and a screenshot/demo using only synthetic content to the README. Do not invent badges or download links before their destinations exist.

These repository settings require an actual hosted repository. Files in this tree do not apply them automatically.

## Before distributing binaries

- Complete [manual validation](manual-validation.md), record hardware/OS/build identifiers, and resolve failures.
- Verify the declared minimum OS and each advertised architecture on real targets. The current script builds only the host architecture.
- Resolve app naming and create an original icon. Keep the bundle identifier stable once distributed.
- Set the version in Resources/Info.plist and move the relevant CHANGELOG.md entries into a dated release section.
- Arrange Developer ID signing and notarization using maintainer-controlled credentials. The current build script uses ad-hoc signing only; do not describe its output as notarized or broadly installable.
- Keep certificates and notarization credentials in the release environment's secret store, never in Git or pull-request workflows.
- Verify the final signed/notarized artifact, test install and launch on a clean Mac, and include checksums with release assets.
- Publish release notes listing tested hardware, known limitations, and exact source commit. Tag only the tested commit.

No workflow currently creates tags, publishes GitHub releases, uploads binaries, or uses signing credentials. Add release automation only after this procedure has been exercised.

## Development DMG and website

The DMG uses Finder to save its icon positions and background during packaging, so packaging requires an interactive macOS session and permission to automate Finder. Eject any existing `OpenLid Install` volume before running it. Only the app and Applications shortcut appear at the image root; license and alpha notes are bundled in the app's Resources directory. Regenerate the committed original icon and installer artwork with `bash scripts/generate-assets.sh`.

Run `bash scripts/build-dmg.sh` to build the app, package a host-architecture DMG, verify its container, and generate a SHA-256 checksum. The image contains an Applications shortcut, license, and alpha installation notes. This does not perform Developer ID signing or notarization. Keep development binaries in a draft release until the distribution checks above are complete.

The static `website/` directory is hosted on Vercel at https://open-lid.vercel.app/. Configure the Vercel project with root directory `website`, framework preset Other, no build command, and output directory `.`. No environment variables are needed. GitHub Pages is not used. Download buttons point to assets hosted separately on GitHub Releases. Its interactive preview is illustrative and does not read the visitor's lid sensor or capture their screen.
