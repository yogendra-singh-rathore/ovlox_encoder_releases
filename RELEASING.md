# How to publish a new Encoder version

For Ovlox India maintainers. End users want [README.md](README.md).

## How the pieces fit

There are two repositories, on purpose:

| Repo | Visibility | Holds |
| --- | --- | --- |
| `ovlox_encoder` | **private** | The C# source, the installer script, and the dev hotel key in `appsettings.json`. |
| `ovlox_encoder_releases` (this one) | **public** | `latest.json`, the docs, and the built `.exe` attached to GitHub Releases. No source. |

The source repo must stay private — its git history contains a working hotel key, which is the AES
key protecting the `/cmd` channel. This repo exists so customers can download the installer without
that history being public.

`latest.json` on the `main` branch is the single source of truth for "what is the current version".
Two things read it:

- **The installed Encoder**, which polls it and prompts the user to update.
- **The website download button**, which uses it to link to the current installer.

Neither needs redeploying when you ship a version. You update `latest.json`, both follow.

## Cutting a release

### 1. Bump the version — in both places

In the **private** `ovlox_encoder` repo:

- `OvloxEncoderService.csproj` → `<AssemblyVersion>`, `<FileVersion>`, `<Version>`
- `installer.iss` → `AppVersion`, `OutputBaseFilename`

They must agree. The Encoder compares its **assembly** version against `latest.json`, so an
installer labelled 2.3.0 that contains a 2.2.0 exe leaves every client prompting forever.
`new-release.ps1` checks this and refuses to continue if they diverge.

Follow the branch convention: new feature → `v3_<name>`, bug fix → `v2.2_<name>`. Merge to `main`
and tag there before releasing.

### 2. Build

In the `ovlox_encoder` repo:

```powershell
dotnet publish -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o publish

& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" installer.iss
```

Output: `installer_output\OvloxEncoderService-Setup-<version>.exe`

### 3. Test the upgrade path before publishing

Install the **previous** version, then run the new installer over it. Confirm:

- The hotel key survives (you are not asked for it again — `appsettings.json` is `onlyifdoesntexist`).
- The tray app comes back up and writes a card.

An upgrade that wipes the hotel key breaks card writing at a live front desk. This step is not
optional.

### 4. Prepare the manifest

From this repo:

```powershell
.\tools\new-release.ps1 -Version 2.3.0 -Notes "What changed","And this too"
```

Add `-Mandatory` for a release users must not postpone. The script verifies the build, computes
the SHA-256 and size, rewrites `latest.json`, and prints the remaining steps.

### 5. Publish — order matters

1. **Create the GitHub Release first** and attach the `.exe`
   ([new release](https://github.com/yogendra-singh-rathore/ovlox_encoder_releases/releases/new)).
   Tag `v<version>`, title `v<version>`. Paste the notes and the SHA-256 into the body.
2. **Check the download URL resolves** in a browser.
3. **Then** commit and push `latest.json`.

If you push the manifest before the asset exists, any client that polls in that window tries to
download a URL that 404s. Asset first, manifest second — always.

### 6. Verify like a customer

- Open the [releases page](https://github.com/yogendra-singh-rathore/ovlox_encoder_releases/releases/latest)
  in a private window. It must be reachable while signed out — if it 404s, the repo is private.
- Check the website download button.
- On a PC with the previous version, confirm the update prompt appears (see below).

## Rolling back a bad release

`latest.json` is the kill switch. Revert it to the previous version and push:

```powershell
git revert HEAD
git push
```

Clients stop offering the bad version within their next check. Then delete or mark the GitHub
Release as a pre-release so nobody downloads it from the web page.

Anyone who already updated must be walked back by hand — the Encoder never downgrades itself.
So: test the upgrade path (step 3).

## Update timing

The Encoder checks on startup and every 6 hours. `latest.json` is served by
`raw.githubusercontent.com`, which caches for ~5 minutes, so a push reaches clients within minutes
of their next check — not instantly. When testing, remember the app has already decided; restart it.

`skipped_version` in `%ProgramData%\Ovlox India\Encoder Service\update.json` records a version the
user chose to skip. Delete that file to make the prompt reappear.

## The SmartScreen problem

The installer is not code-signed, so Windows shows "Windows protected your PC" on download and on
every auto-update. This is the biggest wart in the flow and it will worry hotel staff.

Fixing it needs an **OV or EV code-signing certificate** (~₹25–40k/year; EV clears SmartScreen
immediately, OV builds reputation over time). Until then the README documents the checksum so the
download can at least be verified.
