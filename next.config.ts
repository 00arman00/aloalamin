import type { NextConfig } from "next";
const nextConfig: NextConfig = {
  output: "standalone",
  typescript: { ignoreBuildErrors: true },
  reactStrictMode: false,
  allowedDevOrigins: ["127.0.0.1","localhost","103.231.239.79","marketing.alolabs.net"],
};
export default nextConfig;
