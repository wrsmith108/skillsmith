-- SMI-52: Encrypt pending_key_display to fix security vulnerability
-- Previously stored raw API keys; now uses pgcrypto symmetric encryption
-- Created: 2026-01-27

-- ============================================================================
-- ENABLE PGCRYPTO EXTENSION
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- COLUMN CHANGES: encrypted_key -> payload (BYTEA for encrypted storage)
-- ============================================================================

-- Step 1: Add new BYTEA column for encrypted data
ALTER TABLE pending_key_display
  ADD COLUMN IF NOT EXISTS payload BYTEA;

COMMENT ON COLUMN pending_key_display.payload IS 'PGP-encrypted API key (BYTEA, decrypted only for one-time display)';

-- ============================================================================
-- UPDATE FUNCTION: generate_api_key_for_user
-- Now encrypts the key before storing using pgcrypto
-- ============================================================================
CREATE OR REPLACE FUNCTION generate_api_key_for_user(
  user_id_input UUID,
  tier_input TEXT DEFAULT 'community'
)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  key_bytes BYTEA;
  key_body TEXT;
  full_key TEXT;
  key_hash_val TEXT;
  key_prefix_val TEXT;
  rate_limit_val INTEGER;
  encryption_key TEXT;
BEGIN
  -- Generate 32 random bytes
  key_bytes := gen_random_bytes(32);

  -- Convert to base64url
  key_body := translate(encode(key_bytes, 'base64'), '+/=', '-_');

  -- Create full key with prefix
  full_key := 'sk_live_' || key_body;

  -- Create display prefix
  key_prefix_val := left(full_key, 16) || '...';

  -- Hash the key for storage
  key_hash_val := encode(sha256(full_key::bytea), 'hex');

  -- Get rate limit for tier
  rate_limit_val := CASE tier_input
    WHEN 'enterprise' THEN 300
    WHEN 'team' THEN 120
    WHEN 'individual' THEN 60
    ELSE 30  -- community
  END;

  -- Insert the license key
  INSERT INTO license_keys (
    user_id,
    key_hash,
    key_prefix,
    name,
    tier,
    status,
    rate_limit_per_minute,
    metadata
  ) VALUES (
    user_id_input,
    key_hash_val,
    key_prefix_val,
    'Default API Key',
    tier_input,
    'active',
    rate_limit_val,
    jsonb_build_object(
      'generated_via', 'signup',
      'generated_at', NOW()
    )
  );

  -- Get encryption key from database setting
  -- Must be set via: ALTER DATABASE postgres SET app.pending_key_secret = 'your-secret';
  -- Or via Supabase Dashboard > Database > Extensions > Database Settings
  encryption_key := current_setting('app.pending_key_secret', true);

  -- Fallback to a derived key if setting not configured (not recommended for production)
  IF encryption_key IS NULL OR encryption_key = '' THEN
    -- Use a combination of user_id and a static component as fallback
    -- This is less secure but ensures functionality during development
    encryption_key := encode(sha256(('skillsmith-pending-key-' || user_id_input::text)::bytea), 'hex');
    RAISE WARNING 'app.pending_key_secret not set - using derived key. Set in production!';
  END IF;

  -- Store encrypted key for one-time display
  -- Uses PGP symmetric encryption (AES256 by default)
  INSERT INTO pending_key_display (user_id, payload, expires_at)
  VALUES (
    user_id_input,
    pgp_sym_encrypt(full_key, encryption_key),
    NOW() + INTERVAL '24 hours'
  )
  ON CONFLICT (user_id) DO UPDATE SET
    payload = EXCLUDED.payload,
    expires_at = EXCLUDED.expires_at;

  RETURN full_key;
END;
$$;

-- ============================================================================
-- NEW FUNCTION: decrypt_pending_key
-- Decrypts the pending key for one-time display on account page
-- Automatically deletes the key after retrieval (one-time use)
-- ============================================================================
CREATE OR REPLACE FUNCTION decrypt_pending_key(user_id_input UUID)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  encrypted_payload BYTEA;
  decrypted_key TEXT;
  encryption_key TEXT;
BEGIN
  -- Check if user is requesting their own key
  IF auth.uid() IS NULL OR auth.uid() != user_id_input THEN
    RAISE EXCEPTION 'Unauthorized: can only retrieve own pending key';
  END IF;

  -- Get the encrypted payload
  SELECT payload INTO encrypted_payload
  FROM pending_key_display
  WHERE user_id = user_id_input
    AND expires_at > NOW();

  -- If no pending key found
  IF encrypted_payload IS NULL THEN
    RETURN NULL;
  END IF;

  -- Get encryption key
  encryption_key := current_setting('app.pending_key_secret', true);

  IF encryption_key IS NULL OR encryption_key = '' THEN
    -- Use same fallback derivation as encrypt function
    encryption_key := encode(sha256(('skillsmith-pending-key-' || user_id_input::text)::bytea), 'hex');
  END IF;

  -- Decrypt the key
  BEGIN
    decrypted_key := pgp_sym_decrypt(encrypted_payload, encryption_key);
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to decrypt pending key: %', SQLERRM;
  END;

  -- Delete the pending key (one-time display)
  DELETE FROM pending_key_display WHERE user_id = user_id_input;

  RETURN decrypted_key;
END;
$$;

COMMENT ON FUNCTION decrypt_pending_key IS 'Decrypts and returns pending API key for one-time display, then deletes it';

-- Grant execute to authenticated users (they can only decrypt their own key)
GRANT EXECUTE ON FUNCTION decrypt_pending_key TO authenticated;

-- ============================================================================
-- MIGRATE EXISTING DATA: Encrypt raw keys from old column to new column
-- ============================================================================
DO $$
DECLARE
  r RECORD;
  encryption_key TEXT;
  global_key TEXT;
BEGIN
  -- Get global encryption key (if set)
  global_key := current_setting('app.pending_key_secret', true);

  IF global_key IS NULL OR global_key = '' THEN
    RAISE NOTICE 'app.pending_key_secret not set - using derived keys for migration';
  END IF;

  -- Migrate from old TEXT column (encrypted_key) to new BYTEA column (payload)
  FOR r IN
    SELECT user_id, encrypted_key
    FROM pending_key_display
    WHERE encrypted_key IS NOT NULL
      AND payload IS NULL  -- Only migrate unmigrated rows
  LOOP
    -- Derive key per-user if no global key set
    IF global_key IS NULL OR global_key = '' THEN
      encryption_key := encode(sha256(('skillsmith-pending-key-' || r.user_id::text)::bytea), 'hex');
    ELSE
      encryption_key := global_key;
    END IF;

    -- Encrypt the raw key and store in new column
    UPDATE pending_key_display
    SET payload = pgp_sym_encrypt(r.encrypted_key, encryption_key)
    WHERE user_id = r.user_id;

    RAISE NOTICE 'Encrypted pending key for user %', r.user_id;
  END LOOP;
END;
$$;

-- ============================================================================
-- DROP OLD COLUMN: Remove the raw key column after migration
-- ============================================================================
ALTER TABLE pending_key_display
  DROP COLUMN IF EXISTS encrypted_key;

-- ============================================================================
-- Update schema version
-- ============================================================================
INSERT INTO schema_version (version) VALUES (24) ON CONFLICT DO NOTHING;
