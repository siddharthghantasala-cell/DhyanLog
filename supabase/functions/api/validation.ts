// Pure input-validation helpers for the edge function. Reject malformed input
// at the boundary instead of trusting client-sent values.

export function isFiniteNumber(v: unknown): v is number {
  return typeof v === "number" && Number.isFinite(v);
}

export function validLatitude(v: unknown): v is number {
  return isFiniteNumber(v) && v >= -90 && v <= 90;
}

export function validLongitude(v: unknown): v is number {
  return isFiniteNumber(v) && v >= -180 && v <= 180;
}

/// A trimmed string within [1, maxLen]; null if absent/empty/oversized/non-string.
export function cleanString(v: unknown, maxLen: number): string | null {
  if (typeof v !== "string") return null;
  const t = v.trim();
  if (t.length === 0 || t.length > maxLen) return null;
  return t;
}

/// An optional trimmed string capped at maxLen; null only on the wrong type or
/// oversize. Empty/absent becomes undefined (the field was simply not provided).
export function optionalString(
  v: unknown,
  maxLen: number,
): string | null | undefined {
  if (v == null) return undefined;
  if (typeof v !== "string") return null;
  const t = v.trim();
  if (t.length === 0) return undefined;
  return t.length > maxLen ? null : t;
}

/// A normalized short code (uppercased), or null if it isn't 4–12 alphanumerics.
export function validShortCode(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const t = v.trim().toUpperCase();
  return /^[A-Z0-9]{4,12}$/.test(t) ? t : null;
}
