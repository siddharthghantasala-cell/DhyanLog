import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { resolveAllowOrigin } from "./cors.ts";

Deno.test("resolveAllowOrigin: no allowlist falls back to * (dev)", () => {
  Deno.env.delete("ALLOWED_ORIGINS");
  assertEquals(resolveAllowOrigin("https://anything.test"), "*");
});

Deno.test("resolveAllowOrigin: reflects an allowed origin", () => {
  Deno.env.set(
    "ALLOWED_ORIGINS",
    "https://app.heartfulness.org, https://staging.heartfulness.org",
  );
  assertEquals(
    resolveAllowOrigin("https://staging.heartfulness.org"),
    "https://staging.heartfulness.org",
  );
});

Deno.test("resolveAllowOrigin: unlisted origin gets a non-matching default", () => {
  Deno.env.set("ALLOWED_ORIGINS", "https://app.heartfulness.org");
  // Returns the first allowed origin, which won't match the caller -> browser blocks.
  assertEquals(
    resolveAllowOrigin("https://evil.test"),
    "https://app.heartfulness.org",
  );
  Deno.env.delete("ALLOWED_ORIGINS");
});
