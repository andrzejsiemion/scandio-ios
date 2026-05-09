# Scandio Privacy Policy

**Last updated: May 9, 2026**

## Overview

Scandio prioritizes privacy by keeping all user-entered data exclusively on devices. The developer never transmits information to external servers.

## Data We Collect

### Data you provide

The application stores locally:

* Loyalty card information (name, card number, barcode type, tile color, favorite status)
* Optional store logo images you attach to cards
* Optional category icon you pick or that Apple Intelligence suggests
* Card metadata (creation date, last-used date, sort order)
* App preferences (sort order, theme, language, brightness boost level, duplicate-import policy)

Data remains on your device unless you explicitly export and share backup files yourself.

### Camera and Photo Library

The app requests camera and photo library access solely for:

* **Camera** — scanning a barcode when you add or edit a card
* **Photo Library** — choosing a store logo image to attach to a card

Photos and camera frames stay locally and never upload elsewhere.

## Apple Intelligence (Optional)

When you add or edit a card on a device that supports Apple Intelligence (iOS 26 and later, on capable iPhone models), Scandio may use Apple's on-device Foundation Models framework to suggest a category icon based on the store name you typed.

* The store name is sent only to Apple's on-device language model — it never leaves your device
* No prompt or response is logged or transmitted by Scandio
* The suggestion is editable; tapping any other category overrides it
* On devices without Apple Intelligence, Scandio shows a manual category picker instead

The on-device language model operates under [Apple's own Privacy Policy](https://www.apple.com/legal/privacy/).

## Data We Do Not Collect

* Analytics or usage data
* Advertising identifiers
* Crash reporting services
* Third-party data sharing
* Developer access to your device or app data

## Data Storage and Security

All app data uses Apple's SwiftData framework in the app's private container, protected by iOS security standards. Logo images are stored as external storage references managed by SwiftData.

## Backup and Export

Built-in export creates `.scandiobackup` files locally. The file format is JSON; logo images are embedded as resized base64 data. You control where these files are shared or stored. On import, Scandio asks how to handle duplicates (skip, merge, or add as new) — this can be set as a default in Settings.

## Children's Privacy

The app is not directed at children under 13 and does not knowingly collect information from children.

## Changes to This Policy

Meaningful policy changes publish at `https://siemion.pro/scandio/privacy/` with updated dates.

## Contact

**Andrzej Siemion**  
[andrzej@siemion.pro](mailto:andrzej@siemion.pro)  
[https://siemion.pro/scandio/](https://siemion.pro/scandio/)

---

© 2026 Scandio
