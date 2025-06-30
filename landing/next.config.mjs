/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  basePath: '/pomo',
  assetPrefix: '/pomo',
  images: {
    unoptimized: true,
  },
};

export default nextConfig;