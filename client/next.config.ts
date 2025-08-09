import type { NextConfig } from 'next'
const BACKEND_INTERNAL_PORT = process.env.BACKEND_PORT || '5678'
const isProd = process.env.NODE_ENV === 'production'

const nextConfig: NextConfig = {
  async rewrites() {
    if (isProd) {
      // In production, browsers hit ALB directly; disable internal rewrite
      return []
    }
    // In development (docker-compose), proxy /api to backend container
    return [
      {
        source: '/api/:path*',
        destination: `http://backend:${BACKEND_INTERNAL_PORT}/api/:path*`,
      },
    ]
  },
}

export default nextConfig