#!/usr/bin/env bash
# Single source of truth for the stable test identities used by
# provision_test_users.sh and cleanup_test_users.sh. Don't duplicate this
# list anywhere else — the suffixes below are the same ones each
# supabase/tests/*_test.sh file passes to stable_email().
#
# Supabase's own email-address validation rejects invented/reserved
# domains (e.g. the previous @worklaw-test.test) outright with
# error_code email_address_invalid, so each identity is instead a
# plus-addressed variant of a real mailbox you control — see
# stable_email() in ../_helpers.sh. Requires TEST_EMAIL_BASE to already
# be set (by whichever script sources this file) before sourcing.
#
# Format per entry: "suffix|full_name|organization_name"
source ../_helpers.sh

: "${TEST_EMAIL_BASE:?Set TEST_EMAIL_BASE before sourcing _test_users.sh}"

TEST_USER_SUFFIXES=(
  "stable-anon|Stable Anon|Stable Anon Org"
  "stable-calcrun-a|Stable CalcRun Owner A|Stable CalcRun Org A"
  "stable-calcrun-b|Stable CalcRun Owner B|Stable CalcRun Org B"
  "stable-xorg-a|Stable XOrg Owner A|Stable XOrg Org A"
  "stable-xorg-b|Stable XOrg Owner B|Stable XOrg Org B"
  "stable-sensitive-owner|Stable Sensitive Owner|Stable Sensitive Org"
  "stable-sensitive-member|Stable Sensitive Member|Stable Sensitive Member Org"
  "stable-crud|Stable Crud Owner|Stable Crud Org"
  "stable-isolation-a|Stable Isolation Owner A|Stable Isolation Org A"
  "stable-isolation-b|Stable Isolation Owner B|Stable Isolation Org B"
  "stable-orgimmut-a|Stable OrgImmut Owner A|Stable OrgImmut Org A"
  "stable-orgimmut-b|Stable OrgImmut Owner B|Stable OrgImmut Org B"
  "stable-legalrules|Stable LegalRules User|Stable LegalRules Org"
  "stable-legalvis|Stable LegalVis User|Stable LegalVis Org"
)

TEST_USERS=()
for entry in "${TEST_USER_SUFFIXES[@]}"; do
  IFS='|' read -r suffix full_name org_name <<< "$entry"
  TEST_USERS+=("$(stable_email "$suffix")|$full_name|$org_name")
done
