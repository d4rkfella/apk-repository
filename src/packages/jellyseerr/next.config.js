const path = require("path");
const crypto = require("crypto");
const webpack = require("webpack");
/**
 * @type {import('next').NextConfig}
 */
module.exports = {
  generateBuildId: async () => {
    const commitHash = execSync('git rev-parse --short HEAD').toString().trim()
    return `build-${commitHash}`
  },
  outputFileTracing: true,
  env: {
    commitTag: process.env.COMMIT_TAG || 'local',
  },
  images: {
    remotePatterns: [
      { hostname: 'gravatar.com' },
      { hostname: 'image.tmdb.org' },
      { hostname: 'artworks.thetvdb.com' },
      { hostname: 'plex.tv' },
    ],
  },
  webpack(config) {
    config.output.hashFunction = 'xxhash64';
    config.optimization.moduleIds = 'deterministic';
    config.optimization.chunkIds = 'deterministic';
    config.module.rules.push({
      test: /\.svg$/,
      issuer: /\.(js|ts)x?$/,
      use: ['@svgr/webpack'],
    });
    return config;
  },
  experimental: {
    scrollRestoration: true,
    largePageDataBytes: 256000,
  },
};
