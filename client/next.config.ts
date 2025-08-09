import type { NextConfig } from 'next'
const BACKEND_INTERNAL_PORT = process.env.BACKEND_PORT || '5678'

const nextConfig: NextConfig = {
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: `http://backend:${BACKEND_INTERNAL_PORT}/api/:path*`,
      },
    ]
  },
}

export default nextConfig