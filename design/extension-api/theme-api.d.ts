/**
 * browser.theme — design extension API.
 *
 * Co-designed with design/tokens/schema/tokens.schema.json.
 * Implemented in browser/extensions/ as a Manifest V3 namespace.
 * Secure-fixed tokens (authenticator UI) are never observable here.
 */

declare namespace browser.theme {
  /** W3C DTCG value. Discriminated by $type. */
  type TokenValue =
    | { $type: "color";      $value: string }          // oklch(...) | "#rrggbb" | named ref "{color.brand.9}"
    | { $type: "dimension";  $value: string }          // "12px" | "1rem"
    | { $type: "fontFamily"; $value: string[] }
    | { $type: "fontWeight"; $value: number }
    | { $type: "duration";   $value: string }          // "240ms"
    | { $type: "cubicBezier";$value: [number, number, number, number] }
    | { $type: "number";     $value: number }
    | { $type: "shadow";     $value: ShadowValue }
    | { $type: "typography"; $value: TypographyValue }
    | { $type: "haptic";     $value: string };

  interface ShadowValue {
    offsetX: string; offsetY: string; blur: string;
    spread?: string; color: string;
  }
  interface TypographyValue {
    fontFamily: string[]; fontSize: string;
    fontWeight: number; lineHeight?: string;
  }

  /**
   * The themeable subgraph. Shape matches the token source but with
   * platform-only and secure-fixed branches elided. Readonly from the
   * extension perspective — mutate a copy and pass to set().
   */
  interface ThemeTokens {
    color?:   { brand?: string; danger?: string; success?: string; warning?: string };
    surface?: { canvas?: string; chrome?: string; sunken?: string; overlay?: string };
    text?:    { primary?: string; secondary?: string; link?: string };
    border?:  { subtle?: string; default?: string; focus?: string };
    accent?:  { fill?: string; fillHover?: string; fillSubtle?: string };
    font?:    { family?: { ui?: string[]; mono?: string[] }; weight?: { [k: string]: number } };
    shape?:   { omnibar?: string; contextMenu?: string };
    motion?:  { duration?: { [k: string]: string }; easing?: { [k: string]: [number,number,number,number] } };
    haptic?:  { [event: string]: string };
  }

  interface Theme {
    id: string;                        // uuid
    name: string;                      // user-visible
    author?: string;
    appearance: "light" | "dark" | "auto";
    tokens: ThemeTokens;
    schemaVersion: string;             // semver of tokens.schema.json
    updatedAt: number;                 // epoch ms, sync-assigned
  }

  /** Read the currently active theme. secure-ui paths are absent. */
  function get(): Promise<Theme>;

  /**
   * Atomically write the theme. Unknown paths reject; write to a
   * platform-only or secure-fixed path rejects with ERR_PROTECTED_PATH.
   * By default the write syncs; pass { sync: false } to stay local.
   */
  function set(theme: Theme, options?: { sync?: boolean }): Promise<void>;

  /** Reset to the shipped default (clears user overrides; does not affect sync peers until next write). */
  function reset(): Promise<void>;

  /** Non-persisting preview — used by theme editors. */
  interface PreviewHandle {
    commit(): Promise<void>;
    revert(): Promise<void>;
  }
  function preview(partial: Partial<ThemeTokens>): Promise<PreviewHandle>;

  /** Installed + shipped themes (requires "theme.packages" to install). */
  function listPackages(): Promise<ThemePackage[]>;
  function installPackage(pkg: ThemePackage): Promise<void>;
  function activatePackage(id: string): Promise<void>;

  interface ThemePackage {
    id: string; name: string; author: string;
    light: ThemeTokens; dark: ThemeTokens;
    schemaVersion: string;
    signature?: string;                // optional CWS signing
  }

  /** Emitted after any local or sync-driven theme change. */
  const onChanged: Event<(theme: Theme) => void>;

  /** Runtime info. */
  const apiVersion: string;            // semver of this API
  const schemaVersion: string;         // semver of the token schema
  const platformId: "macos" | "ios" | "windows" | "android" | "linux";

  /** Discover what paths are themeable on this build. Useful for theme editors. */
  function getWritablePaths(): Promise<string[]>;
}

interface Event<T extends (...args: any[]) => void> {
  addListener(cb: T): void;
  removeListener(cb: T): void;
}
