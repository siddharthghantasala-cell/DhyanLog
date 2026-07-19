import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  cleanString,
  optionalString,
  pageLimit,
  pageOffset,
  safeFilterId,
  validLatitude,
  validLongitude,
  validShortCode,
} from "./validation.ts";

Deno.test("latitude/longitude ranges", () => {
  assertEquals(validLatitude(13.08), true);
  assertEquals(validLatitude(-90), true);
  assertFalse(validLatitude(90.1));
  assertFalse(validLatitude("13"));
  assertFalse(validLatitude(NaN));
  assertEquals(validLongitude(80.27), true);
  assertFalse(validLongitude(181));
});

Deno.test("cleanString trims and bounds length", () => {
  assertEquals(cleanString("  HFN-001 ", 128), "HFN-001");
  assertEquals(cleanString("", 128), null);
  assertEquals(cleanString("   ", 128), null);
  assertEquals(cleanString("toolong", 3), null);
  assertEquals(cleanString(42, 128), null);
});

Deno.test("optionalString distinguishes absent from invalid", () => {
  assertEquals(optionalString(undefined, 64), undefined);
  assertEquals(optionalString(null, 64), undefined);
  assertEquals(optionalString("", 64), undefined);
  assertEquals(optionalString("  CTR-1 ", 64), "CTR-1");
  assertEquals(optionalString("x".repeat(65), 64), null); // oversize
  assertEquals(optionalString(7, 64), null); // wrong type
});

Deno.test("validShortCode normalizes and validates", () => {
  assertEquals(validShortCode("ab2k"), "AB2K");
  assertEquals(validShortCode("  XYZ9 "), "XYZ9");
  assertFalse(validShortCode("ab") !== null); // too short
  assertEquals(validShortCode("has space"), null);
  assertEquals(validShortCode("toolongcode13"), null); // 13 chars
  assertEquals(validShortCode(123), null);
});

Deno.test("pageLimit clamps to a bounded window", () => {
  assertEquals(pageLimit(20, 50, 200), 20);
  assertEquals(pageLimit(undefined, 50, 200), 50); // absent -> default
  assertEquals(pageLimit("30", 50, 200), 50); // wrong type -> default
  assertEquals(pageLimit(0, 50, 200), 50); // nonsensical -> default
  assertEquals(pageLimit(-5, 50, 200), 50);
  assertEquals(pageLimit(9999, 50, 200), 200); // never unbounded
  assertEquals(pageLimit(20.7, 50, 200), 20); // floored
});

Deno.test("pageOffset rejects negatives and junk", () => {
  assertEquals(pageOffset(100), 100);
  assertEquals(pageOffset(0), 0);
  assertEquals(pageOffset(-1), 0);
  assertEquals(pageOffset(undefined), 0);
  assertEquals(pageOffset("10"), 0);
  assertEquals(pageOffset(NaN), 0);
});

Deno.test("safeFilterId admits real ids and rejects PostgREST metacharacters", () => {
  assertEquals(safeFilterId("HFN-ABHY-001"), true);
  assertEquals(safeFilterId("abc_123"), true);
  // Anything that could break out of an `or(...)` filter expression.
  assertFalse(safeFilterId("HFN,ABHY"));
  assertFalse(safeFilterId("a.eq.b"));
  assertFalse(safeFilterId("x)or(y"));
  assertFalse(safeFilterId("{braces}"));
  assertFalse(safeFilterId("has space"));
  assertFalse(safeFilterId(""));
  assertFalse(safeFilterId("x".repeat(65)));
});
