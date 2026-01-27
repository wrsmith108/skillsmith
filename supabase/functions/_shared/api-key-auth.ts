/**
 * API Key Authentication Helper
 * @module _shared/api-key-auth
 *
 * SMI-XXXX: API Key Authentication
 *
 * Validates X-API-Key headers against license_keys table.
 * Uses the existing validate_license_key RPC function.
 */

import { createSupabaseAdminClient } from './supabase.ts'
import { hashLicenseKey, isValidKeyFormat } from './license.ts'

/**
 * Authentication result
 */
export interface AuthResult {
  /** Whether authentication succeeded */
  authenticated: boolean
  /** User's subscription tier */
  tier?: 'community' | 'individual' | 'team' | 'enterprise'
  /** Rate limit per minute */
  rateLimit?: number
  /** User ID */
  userId?: string
  /** Key prefix for logging (first 16 chars) */
  keyPrefix?: string
}

/**
 * Extract API key from request headers
 * Supports both X-API-Key header and Bearer token
 *
 * @param req - The incoming request
 * @returns The API key or null if not found
 */
export function extractApiKey(req: Request): string | null {
  // Check X-API-Key header first (preferred)
  const xApiKey = req.headers.get('X-API-Key') || req.headers.get('x-api-key')
  if (xApiKey && isValidKeyFormat(xApiKey)) {
    return xApiKey
  }

  // Check Authorization header with Bearer token
  const authHeader = req.headers.get('Authorization')
  if (authHeader?.startsWith('Bearer sk_live_')) {
    const key = authHeader.slice(7) // Remove 'Bearer '
    if (isValidKeyFormat(key)) {
      return key
    }
  }

  return null
}

/**
 * Authenticate a request using API key
 *
 * @param req - The incoming request
 * @returns Authentication result with tier and rate limit info
 */
export async function authenticateRequest(req: Request): Promise<AuthResult> {
  const apiKey = extractApiKey(req)

  if (!apiKey) {
    return { authenticated: false }
  }

  try {
    // Hash the key for lookup
    const keyHash = await hashLicenseKey(apiKey)
    const keyPrefix = keyHash.substring(0, 16)

    const adminClient = createSupabaseAdminClient()
    const { data, error } = await adminClient.rpc('validate_license_key', {
      key_hash_input: keyHash,
    })

    if (error) {
      console.error('API key validation error:', error)
      return { authenticated: false }
    }

    if (!data || data.length === 0) {
      return { authenticated: false }
    }

    // RPC returns an array, take first row
    const result = Array.isArray(data) ? data[0] : data

    if (!result.is_valid) {
      return { authenticated: false }
    }

    return {
      authenticated: true,
      tier: result.tier as 'community' | 'individual' | 'team' | 'enterprise',
      rateLimit: result.rate_limit,
      userId: result.user_id,
      keyPrefix,
    }
  } catch (err) {
    console.error('API key authentication exception:', err)
    return { authenticated: false }
  }
}

/**
 * Get rate limit for a tier
 * Used as fallback if not returned from RPC
 */
export function getRateLimitForTier(tier: string): number {
  switch (tier) {
    case 'enterprise':
      return 300
    case 'team':
      return 120
    case 'individual':
      return 60
    case 'community':
    default:
      return 30
  }
}
