/**
 * @type {import('next').NextConfig}
 */
module.exports = {
  generateBuildId: () => 'fixed',
  env: {
    commitTag: process.env.COMMIT_TAG || 'local',
    forceIpv4First: process.env.FORCE_IPV4_FIRST === 'true' ? 'true' : 'false',
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
