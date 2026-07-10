-- Seed script for local development: dialers_dev.dialers schema
-- Run against: dialers_dev database (schema: dialers)
-- Usage: psql -U postgres -d dialers_dev -f seed-dialers-local.sql
--
-- Uses 3 fictional companies (9001, 9002, 9003) and matching integration IDs.
-- company_sync is the root — all other tables FK cascade from it.
--
-- This script is destructive: it TRUNCATEs every dialers table first so each
-- run produces a fresh, deterministic dataset. Do NOT run against shared envs.

SET search_path TO dialers;

-- ============================================================
-- 0. Wipe all dialers tables (fresh copy every run)
--    CASCADE handles FK ordering; RESTART IDENTITY resets any sequences.
-- ============================================================
TRUNCATE TABLE
    call_event_external_id,
    call_provider_data,
    company_sync,
    company_sync_properties,
    external_oauth_credentials,
    gong_connect_call_data,
    gong_connect_call_data_ats_data,
    gong_connect_call_data_crm_data,
    gong_connect_call_metadata,
    gong_connect_user_defined_phone_numbers,
    ms_teams_integration,
    providers_salesforce_info,
    recording_import_credentials,
    ringcentral_initial_sync,
    ringcentral_initial_sync_calls_details,
    ringcentral_internal_phones,
    s3_buckets,
    s3_events,
    sms_company_sync,
    sms_conversation_messages_data,
    sms_external_oauth_credentials
RESTART IDENTITY CASCADE;

-- ============================================================
-- 1. company_sync  (root — all other FK chains hang off here)
-- ============================================================
INSERT INTO company_sync
    (integration_id, integration_flavor, company_id, integration_status,
     periodic_sync_from, initial_sync_from, timezone, import_crm_calls_only,
     backfill_requested, connection_method, connection_name,
     create_date_time, update_date_time)
VALUES
    (9001, 'GONG_CONNECT_API',  9001, 'CONNECTED',
     now() - interval '30 days', now() - interval '60 days',
     'America/New_York', false, false, 'oauth', 'Acme Corp',
     now(), now()),

    (9002, 'DIAL_PAD_API',      9002, 'CONNECTED',
     now() - interval '14 days', now() - interval '30 days',
     'America/Chicago', false, false, 'api_key', 'Beta Inc',
     now(), now()),

    (9003, 'AIRCALL_API',       9003, 'DISCONNECTED',
     now() - interval '90 days', now() - interval '120 days',
     'Europe/London', false, false, 'oauth', 'Gamma Ltd',
     now(), now()),

    (9004, 'EIGHT_BY_EIGHT_API', 9001, 'CONNECTED',
     now() - interval '7 days',  now() - interval '14 days',
     'America/Los_Angeles', false, false, 'api_key', 'Acme Corp 8x8',
     now(), now()),

    (9005, 'GONG_CONNECT_API',  9002, 'CONNECTED',
     now() - interval '5 days',  now() - interval '10 days',
     'America/Chicago', false, false, 'oauth', 'Beta Inc Gong Connect',
     now(), now()),

    (9006, 'MS_TEAMS_API',      9003, 'CONNECTED',
     now() - interval '3 days',  now() - interval '6 days',
     'Europe/London', false, false, 'oauth', 'Gamma Ltd MS Teams',
     now(), now()),

    (9007, 'RINGCENTRAL',       9001, 'CONNECTED',
     now() - interval '4 days',  now() - interval '8 days',
     'America/New_York', false, false, 'oauth', 'Acme Corp RingCentral',
     now(), now()),

    (9008, 'SALESFORCE',        9002, 'CONNECTED',
     now() - interval '6 days',  now() - interval '12 days',
     'America/Chicago', false, false, 'oauth', 'Beta Inc Salesforce',
     now(), now())
ON CONFLICT (integration_id) DO NOTHING;


-- ============================================================
-- 2. call_provider_data  (read-only for Supervisor)
-- ============================================================
INSERT INTO call_provider_data
    (company_id, call_id, provider_call_id, integration_id,
     create_date_time, update_date_time)
VALUES
    (9001, 100001, 'gc-call-aaa-001', 9001, now() - interval '2 days', now()),
    (9001, 100002, 'gc-call-aaa-002', 9001, now() - interval '1 day',  now()),
    (9002, 100003, 'dp-call-bbb-001', 9002, now() - interval '3 days', now()),
    (9002, 100004, 'dp-call-bbb-002', 9002, now() - interval '2 days', now()),
    (9001, 100005, '8x8-call-ccc-001', 9004, now() - interval '1 day', now())
ON CONFLICT (call_id) DO NOTHING;


-- ============================================================
-- 3. recording_import_credentials
-- ============================================================
INSERT INTO recording_import_credentials
    (company_id, integration_id, provider_company_identifier, token,
     token_owner, create_date_time, update_date_time)
VALUES
    (9001, 9001, 'acme-gc-provider-id',   'tok_gc_acme_dev_placeholder',
     'admin@acme-corp.test', now(), now()),

    (9002, 9002, 'beta-dp-provider-id',   'tok_dp_beta_dev_placeholder',
     'admin@beta-inc.test',  now(), now()),

    (9001, 9004, 'acme-8x8-provider-id',  'tok_8x8_acme_dev_placeholder',
     'admin@acme-corp.test', now(), now()),

    (9002, 9005, 'beta-gc2-provider-id',  'tok_gc2_beta_dev_placeholder',
     'devops@beta-inc.test', now(), now()),

    (9003, 9003, 'gamma-aircall-id',      'tok_ac_gamma_dev_placeholder',
     'admin@gamma-ltd.test', now(), now())
ON CONFLICT (company_id, integration_id) DO NOTHING;


-- ============================================================
-- 4. external_oauth_credentials
-- ============================================================
INSERT INTO external_oauth_credentials
    (company_id, integration_id, external_account_id, token_owner,
     access_token, access_token_expiration,
     refresh_token, refresh_token_expiration,
     api_end_point, create_date_time, update_date_time)
VALUES
    (9001, 9001, 'gc-ext-acme-001', 'admin@acme-corp.test',
     'access_tok_gc_acme_dev',  now() + interval '1 hour',
     'refresh_tok_gc_acme_dev', now() + interval '30 days',
     'https://api.gongconnect.test/v1', now(), now()),

    (9002, 9002, 'dp-ext-beta-001', 'admin@beta-inc.test',
     'access_tok_dp_beta_dev',  now() + interval '2 hours',
     'refresh_tok_dp_beta_dev', now() + interval '30 days',
     'https://api.dialpad.test/v1', now(), now()),

    (9003, 9003, 'ac-ext-gamma-001', 'admin@gamma-ltd.test',
     'access_tok_ac_gamma_dev', now() - interval '1 hour',  -- expired (disconnected)
     'refresh_tok_ac_gamma_dev', now() + interval '10 days',
     'https://api.aircall.test/v1', now(), now()),

    (9001, 9004, '8x8-ext-acme-001', 'admin@acme-corp.test',
     'access_tok_8x8_acme_dev', now() + interval '3 hours',
     'refresh_tok_8x8_acme_dev', now() + interval '30 days',
     'https://api.8x8.test/v1', now(), now()),

    (9002, 9005, 'gc2-ext-beta-001', 'devops@beta-inc.test',
     'access_tok_gc2_beta_dev', now() + interval '1 hour',
     'refresh_tok_gc2_beta_dev', now() + interval '30 days',
     'https://api.gongconnect.test/v1', now(), now())
ON CONFLICT (company_id, integration_id) DO NOTHING;


-- ============================================================
-- 5. s3_buckets
-- ============================================================
INSERT INTO s3_buckets
    (company_id, bucket, assumed_role_arn, create_date_time, update_date_time)
VALUES
    (9001, 'acme-recordings-dev',  'arn:aws:iam::111111111111:role/acme-recordings-role',  now(), now()),
    (9001, 'acme-backups-dev',     'arn:aws:iam::111111111111:role/acme-backups-role',     now(), now()),
    (9002, 'beta-recordings-dev',  'arn:aws:iam::222222222222:role/beta-recordings-role',  now(), now()),
    (9003, 'gamma-recordings-dev', 'arn:aws:iam::333333333333:role/gamma-recordings-role', now(), now()),
    (9002, 'beta-archive-dev',     'arn:aws:iam::222222222222:role/beta-archive-role',     now(), now())
ON CONFLICT (company_id, bucket) DO NOTHING;


-- ============================================================
-- 6. gong_connect_user_defined_phone_numbers
-- ============================================================
INSERT INTO gong_connect_user_defined_phone_numbers
    (appuser_id, company_id, contact_crm_id, phone_number, phone_number_label,
     email_address, update_identifier, create_date_time, update_date_time)
VALUES
    (501, 9001, 'crm-contact-001', '+15550001001', 'Mobile',  'alice@acme-corp.test', 'uid-001', now(), now()),
    (501, 9001, 'crm-contact-002', '+15550001002', 'Work',    'alice@acme-corp.test', 'uid-002', now(), now()),
    (502, 9001, 'crm-contact-003', '+15550001003', 'Mobile',  'bob@acme-corp.test',   'uid-003', now(), now()),
    (503, 9002, 'crm-contact-004', '+15550002001', 'Mobile',  'carol@beta-inc.test',  'uid-004', now(), now()),
    (504, 9002, 'crm-contact-005', '+15550002002', 'Direct',  'dan@beta-inc.test',    'uid-005', now(), now())
ON CONFLICT (company_id, appuser_id, contact_crm_id, phone_number, update_identifier) DO NOTHING;


-- ============================================================
-- 7. call_event_external_id
-- ============================================================
INSERT INTO call_event_external_id
    (company_id, provider_id, external_id, integration_flavor,
     call_id, activity_id, create_date_time, update_date_time)
VALUES
    (9001, 'gc-call-aaa-001', 'ext-evt-001', 'GONG_CONNECT_API',  100001, 'act-001', now() - interval '2 days', now()),
    (9001, 'gc-call-aaa-002', 'ext-evt-002', 'GONG_CONNECT_API',  100002, 'act-002', now() - interval '1 day',  now()),
    (9002, 'dp-call-bbb-001', 'ext-evt-003', 'DIAL_PAD_API',      100003, 'act-003', now() - interval '3 days', now()),
    (9002, 'dp-call-bbb-002', 'ext-evt-004', 'DIAL_PAD_API',      100004, 'act-004', now() - interval '2 days', now()),
    (9001, '8x8-call-ccc-001','ext-evt-005', 'EIGHT_BY_EIGHT_API', 100005, 'act-005', now() - interval '1 day', now())
ON CONFLICT (company_id, integration_flavor, provider_id) DO NOTHING;


-- ============================================================
-- 8. company_sync_properties  (FK integration_id -> company_sync)
-- ============================================================
INSERT INTO company_sync_properties
    (company_id, integration_id, property_name,
     property_numeric_value, property_date_value, property_string_value,
     create_date_time, update_date_time)
VALUES
    (9001, 9001, 'max_concurrent_downloads', 5, NULL, NULL, now(), now()),
    (9001, 9001, 'last_cursor', NULL, NULL, 'cursor-acme-gc-abc', now(), now()),
    (9002, 9002, 'max_concurrent_downloads', 3, NULL, NULL, now(), now()),
    (9003, 9003, 'disconnect_reason', NULL, now() - interval '2 days', 'token_revoked', now(), now()),
    (9001, 9007, 'rc_extension_count', 12, NULL, NULL, now(), now())
ON CONFLICT (company_id, integration_id, property_name) DO NOTHING;


-- ============================================================
-- 9. gong_connect_call_data  (parent of metadata/ats/crm rows below)
-- ============================================================
INSERT INTO gong_connect_call_data
    (company_id, provider_call_id, app_user_id, call_id, direction,
     recording_rule, deleted, create_date_time, update_date_time)
VALUES
    (9001, 'gc-call-aaa-001', 501, 100001, 'INBOUND',  'ALWAYS',     false, now() - interval '2 days', now()),
    (9001, 'gc-call-aaa-002', 502, 100002, 'OUTBOUND', 'ALWAYS',     false, now() - interval '1 day',  now()),
    (9002, 'gc-call-beta-001', 503, NULL,  'OUTBOUND', 'ON_DEMAND',  false, now() - interval '3 days', now()),
    (9002, 'gc-call-beta-002', 504, NULL,  'INBOUND',  'ALWAYS',     false, now() - interval '2 days', now()),
    (9001, 'gc-call-aaa-003', 501, NULL,   'UNKNOWN',  NULL,         true,  now() - interval '5 days', now())
ON CONFLICT (company_id, provider_call_id) DO NOTHING;


-- ============================================================
-- 10. gong_connect_call_metadata  (FK -> gong_connect_call_data)
-- ============================================================
INSERT INTO gong_connect_call_metadata
    (company_id, provider_call_id, disposition, additional_info,
     create_date_time, update_date_time)
VALUES
    (9001, 'gc-call-aaa-001', 'ANSWERED',   '{"talk_time_sec": 320, "recorded": true}'::jsonb,  now() - interval '2 days', now()),
    (9001, 'gc-call-aaa-002', 'VOICEMAIL',  '{"talk_time_sec": 0, "recorded": false}'::jsonb,   now() - interval '1 day',  now()),
    (9002, 'gc-call-beta-001','ANSWERED',   '{"talk_time_sec": 145}'::jsonb,                    now() - interval '3 days', now()),
    (9002, 'gc-call-beta-002','NO_ANSWER',  NULL,                                               now() - interval '2 days', now()),
    (9001, 'gc-call-aaa-003', 'FAILED',     '{"error": "download_failed"}'::jsonb,              now() - interval '5 days', now())
ON CONFLICT (company_id, provider_call_id) DO NOTHING;


-- ============================================================
-- 11. gong_connect_call_data_ats_data  (FK pair -> gong_connect_call_data)
-- ============================================================
INSERT INTO gong_connect_call_data_ats_data
    (company_id, provider_call_id, candidate_ats_id, ats_type, application,
     create_date_time, update_date_time)
VALUES
    (9001, 'gc-call-aaa-001', 'cand-001', 'GREENHOUSE', '{"job_id": "job-100", "stage": "phone_screen"}'::jsonb, now(), now()),
    (9001, 'gc-call-aaa-002', 'cand-002', 'LEVER',      '{"job_id": "job-101", "stage": "recruiter_call"}'::jsonb, now(), now()),
    (9002, 'gc-call-beta-001','cand-003', 'GREENHOUSE', '{"job_id": "job-200"}'::jsonb, now(), now())
ON CONFLICT (company_id, provider_call_id) DO NOTHING;


-- ============================================================
-- 12. gong_connect_call_data_crm_data  (FK pair -> gong_connect_call_data)
-- ============================================================
INSERT INTO gong_connect_call_data_crm_data
    (company_id, provider_call_id, crm_type, crm_entity_id,
     create_date_time, update_date_time)
VALUES
    (9001, 'gc-call-aaa-001', 'SALESFORCE', '003ABCcontact01', now(), now()),
    (9001, 'gc-call-aaa-001', 'SALESFORCE', '006ABCopp0001',   now(), now()),
    (9001, 'gc-call-aaa-002', 'SALESFORCE', '003ABCcontact02', now(), now()),
    (9002, 'gc-call-beta-001','HUBSPOT',    'hs-contact-555',  now(), now()),
    (9002, 'gc-call-beta-002','HUBSPOT',    'hs-contact-556',  now(), now())
ON CONFLICT (company_id, provider_call_id, crm_type, crm_entity_id) DO NOTHING;


-- ============================================================
-- 13. ms_teams_integration  (integration 9006)
-- ============================================================
INSERT INTO ms_teams_integration
    (company_id, integration_id, ms_tenant_id, region,
     create_date_time, update_date_time)
VALUES
    (9003, 9006, 'ms-tenant-gamma-0001-aaaa-bbbb', 'EU', now(), now())
ON CONFLICT (integration_id) DO NOTHING;


-- ============================================================
-- 14. providers_salesforce_info  (FK integration_id -> company_sync)
-- ============================================================
INSERT INTO providers_salesforce_info
    (company_id, integration_id, call_id, provider_id, provider_call_id,
     salesforce_who_id, salesforce_what_id, create_date_time, update_date_time)
VALUES
    (9002, 9008, 100003, 'sf-provider-beta-01', 'dp-call-bbb-001', '00Qwho0000000001', '006what000000001', now(), now()),
    (9002, 9008, 100004, 'sf-provider-beta-02', 'dp-call-bbb-002', '00Qwho0000000002', '006what000000002', now(), now()),
    (9002, 9008, NULL,    'sf-provider-beta-03', 'dp-call-bbb-003', '00Qwho0000000003', NULL,              now(), now())
ON CONFLICT (company_id, provider_id, provider_call_id) DO NOTHING;


-- ============================================================
-- 15. ringcentral_initial_sync  (FK integration_id -> company_sync)
-- ============================================================
INSERT INTO ringcentral_initial_sync
    (company_id, integration_id, is_import_calls, is_process_calls,
     last_call_timestamp, create_date_time, update_date_time)
VALUES
    (9001, 9007, true, true, now() - interval '1 day', now(), now())
ON CONFLICT (company_id, integration_id) DO NOTHING;


-- ============================================================
-- 16. ringcentral_initial_sync_calls_details
-- ============================================================
INSERT INTO ringcentral_initial_sync_calls_details
    (company_id, integration_id, ringcentral_id, extension_id, is_processed,
     remote_phone_number, call_start_timestamp, duration_in_sec, download_url,
     sdr_app_user_id, direction, rep_phone_num, create_date_time, update_date_time)
VALUES
    (9001, 9007, 'rc-call-0001', 'ext-101', true,  '+15550009001', now() - interval '2 days', 245,
     'https://media.ringcentral.test/rc-call-0001', 501, 'Inbound',  '+15550001000', now(), now()),
    (9001, 9007, 'rc-call-0002', 'ext-102', false, '+15550009002', now() - interval '1 day',  60,
     'https://media.ringcentral.test/rc-call-0002', 502, 'Outbound', '+15550001001', now(), now())
ON CONFLICT (company_id, integration_id, ringcentral_id) DO NOTHING;


-- ============================================================
-- 17. ringcentral_internal_phones
-- ============================================================
INSERT INTO ringcentral_internal_phones
    (companyid, integration_id, phone_number, phone_number_json, update_date_time)
VALUES
    (9001, 9007, '+15550001000', '{"label": "Acme main line", "ext": "101"}', now()),
    (9001, 9007, '+15550001001', '{"label": "Acme sales line", "ext": "102"}', now())
ON CONFLICT (companyid, integration_id, phone_number) DO NOTHING;


-- ============================================================
-- 18. s3_events  (FK integration_id -> company_sync)
-- ============================================================
INSERT INTO s3_events
    (company_id, integration_id, provider, s3_bucket, s3_path, download_url,
     call_duration, call_start_time, provider_call_id, valid_file,
     create_date_time, update_date_time)
VALUES
    (9001, 9004, 'EIGHT_BY_EIGHT_API', 'acme-recordings-dev', 'recordings/2026/06/8x8-call-ccc-001.wav',
     'https://s3.acme.test/8x8-call-ccc-001.wav', 312, now() - interval '1 day', '8x8-call-ccc-001', true,  now(), now()),
    (9002, 9002, 'DIAL_PAD_API',       'beta-recordings-dev', 'recordings/2026/06/dp-call-bbb-001.mp3',
     'https://s3.beta.test/dp-call-bbb-001.mp3', 145, now() - interval '3 days', 'dp-call-bbb-001', true,  now(), now()),
    (9003, 9003, 'AIRCALL_API',        'gamma-recordings-dev', 'recordings/2026/06/ac-call-ddd-001.mp3',
     NULL, 0, now() - interval '4 days', 'ac-call-ddd-001', false, now(), now())
ON CONFLICT (company_id, integration_id, s3_bucket, s3_path) DO NOTHING;


-- ============================================================
-- 19. sms_company_sync
-- ============================================================
INSERT INTO sms_company_sync
    (provider, company_id, integration_id, enabled, periodic_sync_from,
     initial_sync_from, backfill_requested, enabled_date_time,
     dialer_integration_id, connection_name, create_date_time, update_date_time)
VALUES
    ('TWILIO',  9001, 9101, true,  now() - interval '10 days', now() - interval '20 days', false,
     now() - interval '20 days', 9001, 'Acme SMS (Twilio)',   now(), now()),
    ('DIALPAD', 9002, 9102, true,  now() - interval '7 days',  now() - interval '15 days', false,
     now() - interval '15 days', 9002, 'Beta SMS (Dialpad)',  now(), now()),
    ('TWILIO',  9003, 9103, false, NULL,                       NULL,                       true,
     NULL,                       9003, 'Gamma SMS (Twilio)',  now(), now())
ON CONFLICT (company_id, integration_id, provider) DO NOTHING;


-- ============================================================
-- 20. sms_external_oauth_credentials
-- ============================================================
INSERT INTO sms_external_oauth_credentials
    (company_id, integration_id, provider, external_account_id, app_client_id,
     token_owner, access_token, access_token_expiration,
     refresh_token, refresh_token_expiration, scope, api_end_point,
     create_date_time, update_date_time)
VALUES
    (9001, 9101, 'TWILIO',  'tw-ext-acme-001', 'tw-client-acme',
     'admin@acme-corp.test', 'access_tok_tw_acme_dev', now() + interval '1 hour',
     'refresh_tok_tw_acme_dev', now() + interval '30 days', 'sms.read sms.write',
     'https://api.twilio.test/v1', now(), now()),
    (9002, 9102, 'DIALPAD', 'dp-ext-beta-sms-001', 'dp-client-beta',
     'admin@beta-inc.test', 'access_tok_dp_beta_sms_dev', now() + interval '2 hours',
     'refresh_tok_dp_beta_sms_dev', now() + interval '30 days', 'messages.read',
     'https://api.dialpad.test/v1', now(), now())
ON CONFLICT (company_id, integration_id, provider) DO NOTHING;


-- ============================================================
-- 21. sms_conversation_messages_data
-- ============================================================
INSERT INTO sms_conversation_messages_data
    (company_id, conversation_id, message_id, provider,
     provider_conversation_id, provider_message_id, message_ts,
     owner_appuser_id, create_date_time, update_date_time)
VALUES
    (9001, 700001, 800001, 'TWILIO',  'tw-conv-001', 'tw-msg-001', now() - interval '2 days', 501, now(), now()),
    (9001, 700001, 800002, 'TWILIO',  'tw-conv-001', 'tw-msg-002', now() - interval '2 days', 501, now(), now()),
    (9002, 700002, 800003, 'DIALPAD', 'dp-conv-001', 'dp-msg-001', now() - interval '1 day',  503, now(), now())
ON CONFLICT (company_id, provider, provider_conversation_id, provider_message_id) DO NOTHING;


-- ============================================================
-- Verify
-- ============================================================
SELECT 'company_sync'                      AS tbl, count(*) FROM company_sync                      UNION ALL
SELECT 'company_sync_properties',                   count(*) FROM company_sync_properties                    UNION ALL
SELECT 'call_provider_data',                         count(*) FROM call_provider_data                         UNION ALL
SELECT 'recording_import_credentials',               count(*) FROM recording_import_credentials               UNION ALL
SELECT 'external_oauth_credentials',                 count(*) FROM external_oauth_credentials                 UNION ALL
SELECT 's3_buckets',                                 count(*) FROM s3_buckets                                 UNION ALL
SELECT 's3_events',                                  count(*) FROM s3_events                                   UNION ALL
SELECT 'gong_connect_user_defined_phone_numbers',    count(*) FROM gong_connect_user_defined_phone_numbers    UNION ALL
SELECT 'call_event_external_id',                     count(*) FROM call_event_external_id                     UNION ALL
SELECT 'gong_connect_call_data',                     count(*) FROM gong_connect_call_data                     UNION ALL
SELECT 'gong_connect_call_metadata',                 count(*) FROM gong_connect_call_metadata                 UNION ALL
SELECT 'gong_connect_call_data_ats_data',            count(*) FROM gong_connect_call_data_ats_data            UNION ALL
SELECT 'gong_connect_call_data_crm_data',            count(*) FROM gong_connect_call_data_crm_data            UNION ALL
SELECT 'ms_teams_integration',                       count(*) FROM ms_teams_integration                       UNION ALL
SELECT 'providers_salesforce_info',                  count(*) FROM providers_salesforce_info                  UNION ALL
SELECT 'ringcentral_initial_sync',                   count(*) FROM ringcentral_initial_sync                   UNION ALL
SELECT 'ringcentral_initial_sync_calls_details',     count(*) FROM ringcentral_initial_sync_calls_details     UNION ALL
SELECT 'ringcentral_internal_phones',                count(*) FROM ringcentral_internal_phones                UNION ALL
SELECT 'sms_company_sync',                           count(*) FROM sms_company_sync                           UNION ALL
SELECT 'sms_external_oauth_credentials',             count(*) FROM sms_external_oauth_credentials             UNION ALL
SELECT 'sms_conversation_messages_data',             count(*) FROM sms_conversation_messages_data;
