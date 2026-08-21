-- BATCH-00: Platform / Database Namespace Foundation

-- 1. Create schemas
CREATE SCHEMA IF NOT EXISTS private;
CREATE SCHEMA IF NOT EXISTS security;
CREATE SCHEMA IF NOT EXISTS api_v1;
CREATE SCHEMA IF NOT EXISTS internal;

-- 2. Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 3. Create trusted_function_owner role
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'trusted_function_owner') THEN
    CREATE ROLE trusted_function_owner WITH NOLOGIN BYPASSRLS;
  ELSE
    ALTER ROLE trusted_function_owner WITH NOLOGIN BYPASSRLS;
  END IF;
END $$;

-- 4. Default privilege hardening
-- Revoke all default execution on functions from PUBLIC in the defined schemas
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA api_v1 REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA internal REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA security REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Revoke all permissions on schema api_v1 from public and anon roles
REVOKE ALL ON SCHEMA api_v1 FROM PUBLIC;
REVOKE ALL ON SCHEMA api_v1 FROM anon;

-- Grant USAGE on schema api_v1 to authenticated role only
GRANT USAGE ON SCHEMA api_v1 TO authenticated;
