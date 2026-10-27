/** Format API timestamps for Asia/Shanghai (UTC+8) display. */
export function formatAdminTime(iso: string | null | undefined): string {
  if (!iso) return '—'
  // DB/API often emit naive UTC ISO without Z; treat those as UTC.
  const normalized =
    /(?:Z|[+-]\d{2}:?\d{2})$/i.test(iso.trim()) ? iso.trim() : `${iso.trim()}Z`
  const d = new Date(normalized)
  if (Number.isNaN(d.getTime())) return iso
  return new Intl.DateTimeFormat('zh-CN', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).format(d)
}
