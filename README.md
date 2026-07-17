# Ovlox India Encoder — Downloads

Official download point for the **Ovlox India Encoder**, the small Windows app that writes RFID
guest key cards from the Ovlox India Hotel Management System.

It runs quietly in the system tray on the front-desk PC and lets the HMS in your browser talk to
the USB card encoder plugged into that PC.

> ### ⚠️ Proprietary software — not open source
>
> This software is owned exclusively by **Ovlox India**. All rights reserved.
>
> It is published here for the convenience of **authorized Ovlox India customers only**. It is
> licensed to you for use with the Ovlox India HMS at your authorized property — nothing more.
> You may **not** redistribute, republish, mirror, resell, modify, or reverse engineer it.
> Downloading it grants you no ownership and no rights beyond that licence.
>
> See [LICENSE.txt](LICENSE.txt) for the full terms. If you do not agree to them, do not download it.

## Download

### ➡️ [Download the latest version](https://github.com/yogendra-singh-rathore/ovlox_encoder_releases/releases/latest)

Every version is listed on the [Releases](https://github.com/yogendra-singh-rathore/ovlox_encoder_releases/releases)
page. Download `OvloxEncoderService-Setup-<version>.exe` and run it.

## Requirements

- Windows 10 or Windows 11 (64-bit)
- Administrator rights to install (needed once, to register the app and trust its local certificate)
- The Ovlox card encoder connected by USB
- An Ovlox hotel key — your Ovlox India contact provides this; you are asked for it during install

## Installing

1. Run the downloaded `OvloxEncoderService-Setup-<version>.exe`.
2. Windows may show a **"Windows protected your PC"** screen. Click **More info → Run anyway**.
   This appears because the installer is not yet code-signed; see [Security](#security) below.
3. Follow the wizard. Paste your **Ovlox hotel key** when asked.
4. When it finishes, the Ovlox icon appears in your system tray (bottom-right, near the clock).

The app starts automatically each time you log in to Windows. You do not need to open it.

## Updating

The app checks for updates on its own and shows a message in the tray when a new version is ready.
Choose **Update now** and it handles the rest.

You can also update manually at any time: download the newest installer from this page and run it.
Installing over an existing version keeps your hotel key and settings — you will not be asked for
the key again.

## Checking it works

Hover over the tray icon, or right-click it:

| What you see | What it means |
| --- | --- |
| ● Service running | The app is ready and the HMS can reach it. |
| ● Encoder connected | The card encoder is plugged in and detected. |
| ⚠ Encoder NOT detected | Check the encoder's USB cable. Cards cannot be written. |
| ○ Service stopped | Right-click the tray icon and choose **Start**. |

If cards will not write, right-click the tray icon → **Open logs** and send the newest file to
Ovlox India support.

## Security

- The app only listens on `localhost` — nothing on your network or the internet can reach it.
- Card requests are authenticated with your hotel's own key. Requests without it are rejected.
- Installers are published only here. Do not install a copy from any other source.
- Each release below lists a **SHA-256** checksum so you can verify the file you downloaded:

  ```powershell
  Get-FileHash .\OvloxEncoderService-Setup-2.2.0.exe -Algorithm SHA256
  ```

  The result must match the checksum shown on the release. If it does not, delete the file and
  download it again.

> **Note on the SmartScreen warning:** the installer is not yet code-signed, so Windows shows an
> "unrecognised app" warning. Verify the checksum above if you want certainty about the file.

## Support

Contact Ovlox India support, or open an [issue](https://github.com/yogendra-singh-rathore/ovlox_encoder_releases/issues)
on this repository.

---

This repository hosts **release binaries and version information only**. The Encoder's source code
is proprietary and is not public.

**© Ovlox India. All rights reserved.** Proprietary software, licensed — not sold — to authorized
customers only. Redistribution, modification, and reverse engineering are prohibited.
See [LICENSE.txt](LICENSE.txt).
