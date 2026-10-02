# Emerge Kentucky Design System

This app mirrors the design of the organization's website,
**ky.emergeamerica.org** (WordPress, custom `emergeamerica` theme on
WP Engine). Every color and font below was extracted from the site's live
stylesheets on 2026-09-20 — nothing is eyeballed — so anyone can verify or
refresh a token by looking up its CSS selector.

Sources of truth for this document:

- `https://ky.emergeamerica.org/wp-content/themes/emergeamerica/style-child.css`
- `.../style.css` and `.../style-extra.css`
- The state logo PNG the website serves in its nav
  (`EMERGE-STATE-KY-trnsprnt-RGB-600px.png`, bundled here as
  `assets/branding/emerge_ky_logo.png`)

In code, the palette lives in `lib/theme/app_theme.dart` (`AppColors`) and
the reusable widgets in `lib/widgets/emerge/emerge_components.dart`.

## Colors

| Token (`AppColors.`) | Hex | Where the website uses it |
|---|---|---|
| `primary` | `#197278` | Default link + heading color (`a`, `h1–h5`) |
| `primaryDark` | `#095256` | Page titles (`.c-photo-header__title`), button hover states |
| `logoTeal` | `#266670` | The EMERGE KENTUCKY wordmark letters |
| `accentCyan` | `#73CCD8` | Logo drop shadow and border |
| `green` | `#5EB445` | **Contribute** button (`.c-nav__donate-btn`), section-divider dots (`.c-quote__dots`) |
| `periwinkle` | `#5071CE` | **Sign Up** button (`.button--purple`) |
| `navy` | `#29335C` | Periwinkle button hover |
| `orange` | `#FE9D35` | `.button--orange` CTA |
| `crimson` | `#BA4B52` | News link hover / pagination (`style-extra.css`) |
| `textBlack` | `#414141` | Body copy |
| `textMuted` | `#7F7F81` | Muted button/label text |
| `canvas` | `#F6F6F6` | Light section background |
| `border` | `#D9DBDB` | Hairlines and input borders |

Legacy names kept so older screens compile: `secondary` → `green`,
`tertiary` → `crimson`, plus `alertBackground`/`alertAccent` (the site's
form-error red `#D40000`).

## Typography

The website pairs **Montserrat** (headings, buttons, nav — weights 600/700,
buttons uppercase) with **Open Sans** (body). Both are bundled in
`assets/fonts/` (SIL Open Font License) and declared in `pubspec.yaml`, so
they work offline and on every platform.

| Website element | CSS | App equivalent |
|---|---|---|
| Page title | Montserrat 600, 36–48px, `#095256` | `textTheme.headlineLarge/Medium` |
| Section heading | Montserrat 600, `#197278`/`#095256` | `headlineSmall`, `titleLarge` |
| Body | Open Sans, `#414141`, line-height ~1.5 | `bodyLarge/Medium` (default family) |
| Buttons | Montserrat 600, 14px, UPPERCASE, flat, square corners | button themes + `EmergeButton` |

## Components (`lib/widgets/emerge/emerge_components.dart`)

| Widget | Mirrors on the website |
|---|---|
| `EmergeLogo` | The nav wordmark (same PNG the site serves) |
| `EmergeButton` | `.button--*` variants: teal, dark teal, green (Contribute), periwinkle (Sign Up), orange |
| `EmergeQuoteDots` | `.c-quote__dots` — the three green dots dividing sections |
| `EmergeTitleBlock` | `.c-title-block` — centered heading + summary + dots (e.g. "All Alumnae: 334 Ready to Run") |
| `EmergePhotoHeader` | `.c-photo-header` / `.c-text-header` — the page-title band |
| `EmergeActionTile` | The home-page touts (CALENDAR · RECENT NEWS · JOIN OUR MOVEMENT · FOLLOW US) |
| `EmergeBioCard` | `.c-bio-body` — alumna portrait, name in teal, office subtitle, bio |

Where they are used today:

- **Sign In** — white canvas, wordmark, uppercase teal button, periwinkle
  register link (`lib/pages/auth/signin_screen.dart`).
- **Home** — the 2×2 tout grid under the alert banner; Calendar stays
  in-app, the other three open the matching website pages
  (`lib/pages/dashboard/dashboard_screen.dart`).
- **Alumni Directory** — "N Ready to Run" title block with dots; roster rows
  with "Class of YYYY" labels; the detail sheet uses `EmergeBioCard`
  (`lib/features/alumni_directory/`).

## Information architecture mapping

| Website section | App surface |
|---|---|
| Alumnae → All Alumnae / Class of YYYY | **Alumni Directory** tab (search + class filter chips) |
| Get Involved → Upcoming Events | **Events** tab (calendar) |
| News | Home tout → opens the website's `/news/` |
| Get Involved | Home tout → opens the website's `/get-involved/` |
| Contribute | Reserved: `EmergeButton` green variant matches the site's donate button |
| Board of Directors | **Board** area (board members only) |

The website's content data flow (and why the roster is imported rather than
fetched live) is documented in the API repo:
`NPO-Community_api/docs/data-source-of-truth.md`.
