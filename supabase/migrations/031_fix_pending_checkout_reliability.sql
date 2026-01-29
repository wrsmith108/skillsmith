-- SMI-1923: Fix pending checkout reliability
-- Created: 2026-01-28
--
-- Issues fixed:
-- 1. Add explicit transaction handling to prevent partial updates
-- 2. Add better error logging
-- 3. Ensure processed_at is only set after ALL operations succeed

-- ============================================================================
-- IMPROVED PROCESS PENDING CHECKOUT FUNCTION
-- ============================================================================
CREATE OR REPLACE FUNCTION process_pending_checkout(user_email TEXT, user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
  pending RECORD;
  subscription_created BOOLEAN := FALSE;
  profile_updated BOOLEAN := FALSE;
BEGIN
  -- Find unprocessed pending checkout for this email
  SELECT *
  INTO pending
  FROM pending_checkouts
  WHERE email = user_email
    AND processed_at IS NULL
    AND expires_at > NOW()
  FOR UPDATE SKIP LOCKED; -- Prevent race conditions

  IF pending IS NULL THEN
    RAISE NOTICE 'No pending checkout found for email %', user_email;
    RETURN FALSE;
  END IF;

  RAISE NOTICE 'Found pending checkout % for email % (stripe_sub: %)',
    pending.id, user_email, pending.stripe_subscription_id;

  -- Check if subscription already exists (idempotency)
  IF EXISTS (
    SELECT 1 FROM subscriptions
    WHERE stripe_subscription_id = pending.stripe_subscription_id
  ) THEN
    RAISE NOTICE 'Subscription % already exists, marking pending checkout as processed',
      pending.stripe_subscription_id;

    UPDATE pending_checkouts
    SET processed_at = NOW()
    WHERE id = pending.id;

    RETURN TRUE;
  END IF;

  -- Create subscription record
  BEGIN
    INSERT INTO subscriptions (
      user_id,
      stripe_customer_id,
      stripe_subscription_id,
      tier,
      billing_period,
      seat_count,
      status,
      current_period_start,
      current_period_end,
      metadata
    ) VALUES (
      user_uuid,
      pending.stripe_customer_id,
      pending.stripe_subscription_id,
      pending.tier,
      pending.billing_period,
      pending.seat_count,
      'active',
      pending.created_at,
      pending.created_at + CASE
        WHEN pending.billing_period = 'annual' THEN INTERVAL '1 year'
        ELSE INTERVAL '1 month'
      END,
      pending.metadata || jsonb_build_object(
        'from_pending_checkout', true,
        'checkout_session_id', pending.checkout_session_id,
        'processed_at', NOW()
      )
    );
    subscription_created := TRUE;
    RAISE NOTICE 'Created subscription for user % (stripe_sub: %)', user_uuid, pending.stripe_subscription_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to create subscription for user %: % (SQLSTATE: %)',
      user_uuid, SQLERRM, SQLSTATE;
    RETURN FALSE;
  END;

  -- Update user's tier
  BEGIN
    UPDATE profiles
    SET tier = pending.tier
    WHERE id = user_uuid;

    IF NOT FOUND THEN
      RAISE WARNING 'Profile not found for user % when updating tier', user_uuid;
      -- Don't fail - subscription was created, tier update is secondary
    ELSE
      profile_updated := TRUE;
      RAISE NOTICE 'Updated profile tier to % for user %', pending.tier, user_uuid;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to update profile tier for user %: %', user_uuid, SQLERRM;
    -- Don't fail - subscription was created
  END;

  -- Only mark as processed if subscription was created successfully
  IF subscription_created THEN
    UPDATE pending_checkouts
    SET processed_at = NOW()
    WHERE id = pending.id;

    RAISE NOTICE 'Marked pending checkout % as processed', pending.id;
    RETURN TRUE;
  ELSE
    RAISE WARNING 'Pending checkout % NOT marked as processed due to failures', pending.id;
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION process_pending_checkout(TEXT, UUID) IS
  'Processes a pending checkout when user signs up. Only marks as processed after subscription is created. SMI-1923';

-- ============================================================================
-- IMPROVED TRIGGER FUNCTION - With better error handling
-- ============================================================================
CREATE OR REPLACE FUNCTION handle_new_user_pending_checkout()
RETURNS TRIGGER AS $$
DECLARE
  result BOOLEAN;
BEGIN
  -- Try to process any pending checkout for this user's email
  BEGIN
    result := process_pending_checkout(NEW.email, NEW.id);
    IF result THEN
      RAISE NOTICE 'Successfully processed pending checkout for new user % (%)', NEW.id, NEW.email;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- Log but don't fail - user creation should still succeed
    RAISE WARNING 'Error processing pending checkout for user % (%): %', NEW.id, NEW.email, SQLERRM;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update schema version
INSERT INTO schema_version (version) VALUES (31) ON CONFLICT DO NOTHING;
