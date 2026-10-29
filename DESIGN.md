# VenturePlus Flutter App — Design System

**Design owner reference:** This file is the primary UI/UX source of truth for Codex.  
**Brand:** Venture Plus / EstateHub real-estate platform  
**Platform:** Flutter, Android-first, iOS-compatible  
**Theme:** Light mode only; English only

## 1. Design intent

Create a calm, premium, trustworthy property experience. Preserve Venture Plus brand recognition and the website's business meaning, but redesign layouts for mobile ergonomics. Prioritize clear property imagery, readable data, confident actions and low cognitive load. Avoid a generic admin template look, excessive gradients, glassmorphism, oversized rounded cards everywhere, and decorative animation.

Inspect and reuse the actual logo asset from the repository before creating a substitute. Preserve aspect ratio and provide suitable light-background clear space. If the source logo is low-resolution, use the original for the demo and document the limitation rather than silently inventing a replacement.

## 2. Colour tokens

Use these initial tokens unless contrast testing or the actual logo requires a documented adjustment.

| Token | HEX | Intended use |
|---|---|---|
| `sage-900` | `#263D32` | Strong brand text, selected navigation, high-emphasis brand surfaces |
| `sage-700` | `#426653` | Primary brand controls and active states |
| `sage-500` | `#789681` | Secondary accents, icons, subdued brand details |
| `sage-100` | `#E8EFE9` | Soft selected surfaces and badges |
| `walnut-900` | `#3D2B22` | Main warm dark text and premium secondary emphasis |
| `walnut-700` | `#624638` | Secondary brand surfaces and supporting emphasis |
| `amber-500` | `#D99A32` | Accent for highlights, small indicators and key moments |
| `amber-100` | `#FFF1D4` | Accent backgrounds |
| `background` | `#F8F8F4` | Main app background |
| `surface` | `#FFFFFF` | Cards, sheets, forms and navigation surfaces |
| `surface-muted` | `#F0F1EB` | Secondary surfaces and subtle grouping |
| `text-primary` | `#202820` | Main body and heading text |
| `text-secondary` | `#626B62` | Supporting labels and metadata |
| `border` | `#DDE2DA` | Dividers, outlines and card borders |
| `success` | `#2F6B46` | Successful completion |
| `warning` | `#8A5A0A` | Warning states |
| `error` | `#B42318` | Errors and destructive states |
| `info` | `#285E8E` | Informational messages |

### 60/30/10 rule

Use as an overall visual balance, not a rigid per-screen formula:
- **60%** neutral backgrounds and whitespace (`background`, `surface`, `surface-muted`).
- **30%** brand surfaces and hierarchy (sage and walnut, mostly light tints; use dark fills selectively).
- **10%** accent emphasis (amber) for a small number of important elements.

Do not use amber as the primary colour for every button or large text surface. Avoid low-contrast sage text on white. Verify text and control contrast against WCAG AA targets where applicable; if a token fails, adjust the foreground/background pairing and document the change.

## 3. Typography

Use a legible, modern sans-serif. Preferred first option: **Inter** if a legally usable font asset or package is already available and can be bundled appropriately; otherwise use the platform's reliable sans-serif fallback. Do not rely on a network font download for first launch.

Suggested type scale:
- Display: 30–34 sp, weight 700, tight line height; use sparingly.
- Screen title: 24–28 sp, weight 700.
- Section title: 18–20 sp, weight 600–700.
- Card title: 16–18 sp, weight 600.
- Body: 14–16 sp, weight 400–500.
- Supporting label: 12–14 sp; do not use tiny text for important information.
- Numeric KPI: 24–32 sp, weight 700; keep labels clear and units visible.

Use sentence case. Avoid all-caps labels except very short status tags. Allow text scaling; don't clip long names, prices, addresses, or status descriptions.

## 4. Layout, spacing and shape

Use a consistent 4-point base spacing system. Suggested scale: 4, 8, 12, 16, 20, 24, 32, 40, 48.
- Phone page horizontal inset: 16–20 dp.
- Tablet content max width: approximately 900–1100 dp depending on the screen; center content rather than stretching text across the whole display.
- Form field height: generally 52–56 dp.
- Primary action target: at least 48 dp high.
- Icon tap target: at least 48 × 48 dp even if the icon itself is smaller.
- Card radius: 12–16 dp.
- Input/button radius: 12 dp unless a pill is meaningful for a chip or compact status.
- Border: 1 dp subtle neutral line. Use shadow sparingly.
- Use safe areas and account for keyboard insets. No fixed-height page layouts that overflow when the keyboard or large text is enabled.

Prefer clean alignment and useful whitespace over nested cards. Property photos should be large enough to evaluate the property; crop consistently but preserve a path to view the full image.

## 5. Navigation

Use role-aware bottom navigation for the 3–5 highest-frequency destinations per role. Secondary sections belong in a drawer or profile/menu sheet. Do not guess the final tabs: derive them from `GUIDELINES.md`'s verified screen inventory.

Navigation requirements:
- Display active selection clearly using sage.
- Use both icon and text label for primary destinations.
- Keep navigation placement and behaviour consistent across roles.
- Admin can have more secondary sections; do not cram all admin modules into bottom navigation.
- Use platform-appropriate safe areas and respect Android system back.
- Confirm before destructive navigation when a form contains unsaved changes.
- Unauthorized routes show a safe access-denied state and return to an allowed screen.

## 6. Login and role selection

The login screen contains:
- Venture Plus logo and a concise welcome message.
- Email and password fields with labels, validation and password visibility toggle.
- Three clearly separated demo-prefill actions: **Sign in as Admin**, **Sign in as Employee**, **Sign in as Customer**.
- A primary **Sign in** action.
- An explicit **Offline Demo** entry when offline or when the user chooses local demonstration mode.
- Clear connection/mode state.

Demo-prefill buttons only fill the fields; they do not claim successful authentication. The values provided by the owner are configured as demo prefill values. The app must report invalid/unverified credentials honestly. Offline demo must be labelled and visually distinct enough to prevent confusion with connected mode.

## 7. Component specifications

### Buttons
- Primary: sage-700 fill, white label, 12 dp radius.
- Secondary: surface fill, sage/walnut text, 1 dp border.
- Tertiary: text-only, used for low-priority actions.
- Destructive: error colour and explicit confirmation when appropriate.
- Disabled: clearly disabled with readable label; never communicate state by colour alone.
- Loading: keep button dimensions stable, show compact progress indicator and prevent duplicate submissions.
- Tap feedback: subtle scale down to about 0.98 and/or tonal overlay, then return smoothly. Keep total feedback short, approximately 100–180 ms.
- No action should be delayed to finish an animation.

### Inputs
- Persistent labels; placeholders are examples, not the only label.
- Focus: clear sage border and accessible focus state.
- Invalid: error border plus specific helper text and semantic announcement.
- Password visibility toggle has an accessible label.
- Disable submit while a request is pending; prevent duplicate requests.

### Cards and lists
- Use consistent padding and alignment.
- Property cards prioritize image, property/venture name, location, key plot details, availability/status and the next action.
- Avoid fake property data in connected mode.
- Show data source/mode when demo sample data is displayed.
- Support list/grid changes responsively where appropriate; do not force dense grids on narrow phones.

### Status badges
Use concise text plus colour/icon; examples must come from real backend status enums. Do not invent statuses. Ensure contrast and do not rely on colour alone.

### Dialogs and sheets
Use bottom sheets for mobile filters and quick actions; use dialogs for confirmation and short decisions. Long forms belong on a full screen. Preserve keyboard and screen-reader usability.

### Dashboard metrics
- Use readable KPI cards with label, value and unit.
- Show skeletons per metric while loading.
- Use actual backend data in connected mode. If a metric is unavailable, show “Unavailable” or omit it rather than fabricate a number.
- Keep charts simple, labelled and scrollable on small screens.

## 8. Loading, empty, error and offline states

### Branded startup
Use a brief logo-first startup screen with neutral background and restrained sage/amber detail. Do not simulate a long loading delay. Startup should resolve quickly to the saved session, login, or offline-demo entry.

### Skeletons
- Use skeleton shapes that match the final content geometry.
- Use a low-contrast neutral/sage tint, not bright flashing shimmer.
- Respect reduced-motion settings; replace animated shimmer with a static placeholder when motion is reduced.
- Avoid layout shifts when real data arrives.

### Progress
- Use inline progress for small actions and full-page progress only when the entire screen cannot render without data.
- Uploads show progress when available and a clear retry option on failure.
- Avoid indefinite spinners; use timeouts and actionable error messages.

### Empty states
Each empty state contains a clear title, one-sentence explanation and a relevant action if permitted. Examples: no favorites, no assigned leads, no ventures available. Do not show an “Add” action to roles without create permission.

### Errors
- Human-readable, specific, actionable copy.
- Retry where safe.
- Do not expose stack traces, tokens, SQL errors or secrets.
- Distinguish validation errors, permission errors, server errors and offline errors.
- On 401, handle session expiry and return to login safely; on 403, explain lack of permission without exposing protected data.

### Offline
Show a persistent but unobtrusive **Offline Demo** banner/chip when using local sample data. When connected mode loses connectivity, show stale-data status and last-updated time where available. Never silently swap real data for sample data.

## 9. Motion system

Motion should be subtle, short and purposeful:
- Button feedback: 100–180 ms.
- Small state changes (chip selection, favourite toggle): 140–200 ms.
- Page transitions: approximately 180–260 ms.
- Sheets/dialogs: approximately 180–240 ms.
- Skeleton shimmer: slow and low contrast; disable or simplify under reduced motion.
- Use ease-out for entrances and ease-in for exits.
- Avoid spring/bounce effects on business dashboards, long hero animations, parallax, and repeated decorative motion.
- Keep navigation and actions responsive on lower-end devices.

Respect OS accessibility/reduced-motion settings. If animation is reduced, use fades or immediate state changes. Never encode essential information solely in an animation.

## 10. Responsive rules

Design phone-first, then adapt:
- Narrow phone: single-column forms and lists; filters in a bottom sheet; no horizontal overflow.
- Larger phone: use available width without stretching text.
- Tablet/iPad: centered max-width content, two-column dashboards where useful, side navigation/drawer when it improves efficiency, master-detail layouts for lists and details where appropriate.
- Landscape: preserve readable content and usable controls.
- Dynamic text: support text scaling without clipping or overlapping controls.
- Keyboard: scroll focused fields into view; ensure submit actions remain reachable.
- Images: preserve aspect ratio and use placeholders while loading.

Do not define layout only by specific device names. Use responsive constraints/breakpoints and test representative widths.

## 11. Accessibility

- Provide semantic labels for icon-only controls.
- Support screen readers and logical traversal order.
- Maintain readable contrast and do not rely on colour alone.
- Respect text scaling and system reduced-motion preferences.
- Provide visible focus/pressed/selected/disabled states.
- Error messages must be associated with fields and announced where feasible.
- Use sufficiently large tap targets.
- Ensure modal focus, dismiss actions and Android back behaviour are predictable.

## 12. Images and uploads

- Reuse the actual Venture Plus logo.
- Property images use a consistent ratio and a neutral placeholder.
- Preserve the ability to view images larger where a property/layout image is important.
- Upload controls must show selected file names/thumbnails, file constraints, progress, success and failure.
- Ask permission only when camera/gallery functionality is invoked.
- Never show a success state until the backend or local data source confirms success.

## 13. Implementation and visual QA

Codex must implement reusable theme tokens and components rather than scattered hardcoded values. Before completion:
- Run app at representative phone and tablet widths.
- Check all roles and navigation paths.
- Check loading, empty, error, offline and success states.
- Check large text, screen-reader labels and reduced motion.
- Verify no overflow, clipped controls, fake metrics, dead buttons or broken back navigation.
- Capture screenshots of login and key screens per role for review.
- Report any untested iOS-specific behaviour honestly.
