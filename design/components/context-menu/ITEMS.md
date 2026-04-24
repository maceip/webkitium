# Context Menu Items — Cross-Browser Survey (2025–2026)

Survey of the seven right-click surfaces across Chrome 125+ (**C**), Safari 18+ (**S**), Firefox 130+ (**F**), Arc (**A**), Edge Copilot-era (**E**), Brave (**B**), Orion (**O**) on a clean install. Clipboard basics (Copy / Paste / Select All / Undo / Redo / Cut) and extension-contributed items are explicitly excluded per scope.

Canonical labels follow Chrome's current UI, which maps to the `IDC_CONTENT_CONTEXT_*` identifiers in `chrome/app/chrome_command_ids.h`.

## Page context (empty page area)

| Label | Browsers | Note |
|---|---|---|
| Back | C S F A E B O | Navigate history back; disabled if none. |
| Forward | C S F A E B O | Navigate history forward. |
| Reload | C S F A E B O | Firefox labels "Reload"; Safari "Reload Page". |
| Save as… | C S F A E B O | Writes full page (HTML/MHTML/webarchive). |
| Print… | C S F A E B O | Opens print preview. |
| Cast… | C — — — E B — | Chrome/Edge/Brave Media Router. |
| Send to your devices | C — — — E — — | Tab push to signed-in devices. |
| Create QR code for this page | C — — — E B — | Inline QR generator. |
| Translate to *\<lang\>* | C S F — E B — | Safari/FF gated on site language detection. |
| Take Screenshot | — — F — — — — | FF built-in region/full-page screenshot. |
| View page source | C S F A E B O | Safari requires Develop menu enabled. |
| Inspect | C S F A E B O | Opens devtools; Safari = "Inspect Element". |
| Show Reader | — S — — — — O | Safari/Orion reader toggle. |
| Ask Copilot about this page | — — — — E — — | Edge AI sidebar entry. |
| Add to Reading List | — S — A — — O | |
| Share… | — S — A — — O | Native share sheet. |

**Must-have:** Back, Forward, Reload, View page source, Inspect, Save as… (Print is arguably 7th).

**AI-era flags:** Edge "Ask Copilot about this page"; Safari 18.2+ exposes "Summarize" on reader-eligible pages via Apple Intelligence.

## Link context

| Label | Browsers | Note |
|---|---|---|
| Open link in new tab | C S F A E B O | |
| Open link in new window | C S F A E B O | |
| Open link in incognito/private window | C S F A E B O | Brave adds "…in Private Window with Tor". |
| Open in Little Arc | — — — A — — — | Ephemeral peek window. |
| Open link in new Split View | — — — A — — — | Arc-specific. |
| Save link as… | C S F A E B O | |
| Copy link address | C S F A E B O | Safari = "Copy Link". |
| Copy link with highlight | — — — — — — O | Orion text-fragment deep link. |
| Download linked file | — S — — — — O | WebKit variant of Save as. |
| Add link to Reading List | — S — A — — O | |
| Share link… | — S — A — — O | |

**Must-have:** Open in new tab, Open in new window, Open in private window, Save link as…, Copy link address.

## Image context

| Label | Browsers | Note |
|---|---|---|
| Open image in new tab | C S F A E B O | |
| Save image as… | C S F A E B O | |
| Copy image | C S F A E B O | Bitmap to clipboard. |
| Copy image address | C S F A E B O | |
| Search image with Google Lens | C — — — — — — | Chrome 127+ replaced "Search Google for image"; opens drag-to-crop overlay. |
| Visual search in Bing / Copilot | — — — — E — — | Edge's Lens equivalent. |
| Search image with DuckDuckGo | — — — — — B — | Brave default. |
| Search image on the web | — — F — — — — | FF uses default engine. |
| Set as desktop background | C — — — — — — | Windows/ChromeOS only. |
| Email image… | — S — — — — — | macOS Mail handoff. |
| Use image as… (wallpaper/lockscreen) | — S — — — — — | iPadOS/macOS share. |
| Share image… | — S — A — — O | |

**Must-have:** Open image in new tab, Save image as…, Copy image, Copy image address, Reverse image search (engine-pluggable).

**AI-era flags:** Chrome's "Search with Google Lens" is now a *region* selector, not a per-image action; Edge routes image queries through Copilot's multimodal backend (implicit re-ranking, not a new label). Apple Intelligence adds "Look Up" with visual-intelligence results on selected images in Safari 18.2.

## Text selection context

| Label | Browsers | Note |
|---|---|---|
| Search \<engine\> for "\<selection\>" | C S F A E B O | Engine = default search; label interpolates selection. |
| Look Up "\<selection\>" | — S — — — — O | Dictionary/visual-intelligence popover. |
| Translate "\<selection\>" | C S F — E — — | FF shows when Translator model present. |
| Read aloud | — S — — E — — | Safari "Speech → Start Speaking". |
| Writing Tools ▸ | — S — — — — — | Apple Intelligence submenu (Proofread, Rewrite, Summary, Key Points, List, Table, ChatGPT). |
| Ask Copilot | — — — — E — — | Opens sidebar pre-filled with selection. |
| Ask Leo | — — — — — B — | Brave's local/hosted AI. |
| Share Quote | — — — A — — — | Arc image-quote link. |
| Copy Link to Highlight | C — — — — — O | Chrome 123+ text-fragment URL. |
| Print… (selection) | C — F — E B — | Prints selection only. |
| Create QR code for this selection | C — — — E B — | |
| Add Note | — S — — — — — | macOS Notes app handoff. |

**Must-have:** Search \<engine\> for selection, Translate, Look Up / define, Copy Link to Highlight, Print selection.

**AI-era flags:** Safari **Writing Tools** submenu is the defining 2024–25 addition. Edge **Ask Copilot** and Brave **Ask Leo** are the competitive equivalents. Chrome has resisted adding an AI entry here through 125, routing it through the side panel instead.

## Editable field context (textarea/input)

| Label | Browsers | Note |
|---|---|---|
| Spellcheck ▸ (suggestions, language, Add to dictionary) | C S F A E B O | Top of menu when misspelling detected. |
| Writing direction ▸ (LTR/RTL) | C S F — E B O | |
| Emoji & Symbols | — S — — — — O | macOS character picker. |
| Autofill ▸ (addresses, payments, passwords) | C S F — E B O | Sub-menu with saved profiles. |
| Use password | — S — — — — O | Safari Keychain pick. |
| Suggest strong password | C S F — E B O | On password fields. |
| Writing Tools ▸ | — S — — — — — | Same submenu as selection. |
| Rewrite with Copilot | — — — — E — — | |
| Dictation / Start Speaking | — S — — — — — | macOS dictation handoff. |

**Must-have:** Spellcheck suggestions + Add to dictionary, Autofill picker, Suggest strong password, Writing direction.

## Tab strip context

| Label | Browsers | Note |
|---|---|---|
| New tab to the right | C — — A E B O | |
| Reload | C S F A E B O | |
| Duplicate | C S F A E B O | |
| Pin / Unpin | C S F A E B O | |
| Mute site / Unmute site | C S F A E B O | Per-site in Chrome, per-tab elsewhere. |
| Add tab to new group | C — — — E B — | Chrome tab groups. |
| Add tab to group ▸ | C — — — E B — | Existing group picker. |
| Remove from group | C — — — E B — | |
| Move tab to new window | C S F A E B O | |
| Move tab to another window ▸ | C S F — E B O | |
| Send tab to your devices | C — — — E — — | |
| Close | C S F A E B O | |
| Close other tabs | C S F A E B O | |
| Close tabs to the right | C S F A E B O | |
| Close tabs to the left | — S — A — — O | |
| Reopen closed tab | C S F A E B O | |
| Bookmark all tabs | — — F — — — — | |
| Add to Space / Pin to Top | — — — A — — — | Arc-specific. |
| Archive tab | — — — A — — — | 12–24h auto-archive hook. |
| Copy tab URL | — — — A — — O | |

**Must-have:** New tab to the right, Reload, Duplicate, Pin, Mute, Move to new window, Close, Close others, Close to the right, Reopen closed tab.

## Omnibar / address bar context

| Label | Browsers | Note |
|---|---|---|
| Paste and go / Paste and search | C S F A E B O | Single item; swaps wording based on clipboard content. |
| Edit search engines… | C — F — E B — | |
| Show full URL (always) | C S — — E B O | Toggle trims `https://` and `www.`. |
| Show Suggestions | — S — — — — O | Toggle omnibox autocomplete. |
| Voice search | C — — — — — — | Mic shortcut on ChromeOS. |

**Must-have:** Paste and go (context-aware), Edit search engines, Show full URL toggle.

---

## Design takeaways for webkitium

1. **Core cross-browser baseline is ~55 unique items** across the seven surfaces; a minimal shipping set is ~32.
2. **AI entry points are now expected on two surfaces only:** text selection and editable fields. Treat them as a single pluggable "Ask \<assistant\>" verb, not per-vendor labels.
3. **Text fragments** (Copy Link to Highlight) graduated from experimental to default in Chrome 123 and Orion 1.0 — include from day one.
4. **Tab groups** are a Chromium convention; if webkitium supports groups, the three-item cluster (Add to new group / Add to group / Remove from group) is non-negotiable.
5. **Safari's Writing Tools submenu** is the only item on the list that is *nested* by default — every other surface is flat. Keep menus flat unless an item has a genuine 3+ option fan-out.
6. **Share** and **Reading List** entries only appear on platforms with OS-level equivalents; gate behind a capability check rather than ship stubs.

Sources:
- [chrome/app/chrome_command_ids.h — Chromium Code Search](https://source.chromium.org/chromium/chromium/src/+/HEAD:chrome/app/chrome_command_ids.h)
- [chrome.contextMenus API — Chrome for Developers](https://developer.chrome.com/docs/extensions/reference/api/contextMenus)
- [menus.ContextType — MDN](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/menus/ContextType)
- [Search with Google Lens in Chrome — Google Help](https://support.google.com/chrome/answer/15086890)
- [Getting started with Copilot in Microsoft Edge — Microsoft Support](https://support.microsoft.com/en-us/topic/getting-started-with-copilot-in-microsoft-edge-ab0153dc-ad31-4de6-899a-802223821a9d)
- [Apple Intelligence Writing Tools — MacRumors guide](https://www.macrumors.com/guide/apple-intelligence-writing-tools/)
- [Apple introduces AI-powered Writing Tools in Safari 18.1 — ppc.land](https://ppc.land/apple-introduces-ai-powered-writing-tools-in-safari-18-1-and-across-operating-systems/)
- [Little Arc: Quick Lookups & Instant Triaging — Arc Help Center](https://resources.arc.net/hc/en-us/articles/19235387524503-Little-Arc-Quick-Lookups-Instant-Triaging)
- [Copy Link with Highlight — Kagi Orion Docs](https://help.kagi.com/orion/features/copy-link-with-highlight.html)
- [Orion browser features — Kagi Blog](https://blog.kagi.com/orion-features)
- [Google Lens new UI on Chrome 127 — Android Police](https://www.androidpolice.com/google-circle-to-search-makeover-for-lens-rolling-out-chrome-desktop/)
