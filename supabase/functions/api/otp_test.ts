import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { maskContact } from "./otp.ts";

Deno.test("maskContact hides the email local part but keeps the domain", () => {
  assertEquals(maskContact("asha.rao@example.org"), "a***@example.org");
});

Deno.test("maskContact keeps only the last 4 digits of a phone", () => {
  assertEquals(maskContact("+91 90000 11111"), "***1111");
});

Deno.test("maskContact is empty for blank input", () => {
  assertEquals(maskContact("   "), "");
});
