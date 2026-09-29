export function setLanguageCookie(locale: string): void {
  document.cookie = `lang=${locale}; path=/; max-age=${60 * 60 * 24 * 365}; samesite=lax`;
}
