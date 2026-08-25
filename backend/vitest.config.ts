import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // convex-test runs functions in an isolate that mimics the Convex V8
    // runtime, which is the point: it is where `crypto.subtle` inside a
    // MUTATION either works or does not.
    environment: "edge-runtime",
    server: { deps: { inline: ["convex-test"] } },
    include: ["convex/**/*.test.ts"],
  },
});
