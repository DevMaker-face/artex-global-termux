import createNextIntlPlugin from "next-intl/plugin";

import { fileURLToPath } from "node:url";

const isExport = process.env.NEXT_EXPORT === "1";
const isMock = process.env.NEXT_PUBLIC_MOCK === "1";

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Disable turbopack - not supported on Android/ARM64
  // Use Webpack instead
  allowedDevOrigins: ["*.*.*.*"],
  compiler: {
    removeConsole: process.env.NODE_ENV === "production",
  },
  ...(isExport
    ? {
        output: "export",
        images: { unoptimized: true },
        trailingSlash: true,
      }
    : isMock
      ? {
          images: { unoptimized: true },
        }
      : {
          async rewrites() {
            const backend = process.env.AUTOPENTEST_API ?? "http://localhost:8787";
            return [{ source: "/api/:path*", destination: `${backend}/api/:path*` }];
          },
        }),
  // Disable reactCompiler which needs native bindings
  reactCompiler: false,
};

const withNextIntl = createNextIntlPlugin("./src/i18n/request.ts");

export default withNextIntl(nextConfig);
