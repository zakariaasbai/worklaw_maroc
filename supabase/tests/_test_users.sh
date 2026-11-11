#!/usr/bin/env bash
# Single source of truth for the stable test identities used by
# provision_test_users.sh and cleanup_test_users.sh. Don't duplicate this
# list anywhere else — both scripts source this file.
#
# `.test` is an IETF/ICANN reserved special-use TLD (RFC 2606 / RFC
# 6761) — guaranteed never to be a real, registrable domain, unlike
# `.local` (reserved for mDNS/link-local use, not for this purpose).
#
# Format per entry: "email|full_name|organization_name"
TEST_USERS=(
  "stable-anon@worklaw-test.test|Stable Anon|Stable Anon Org"
  "stable-calcrun-a@worklaw-test.test|Stable CalcRun Owner A|Stable CalcRun Org A"
  "stable-calcrun-b@worklaw-test.test|Stable CalcRun Owner B|Stable CalcRun Org B"
  "stable-xorg-a@worklaw-test.test|Stable XOrg Owner A|Stable XOrg Org A"
  "stable-xorg-b@worklaw-test.test|Stable XOrg Owner B|Stable XOrg Org B"
  "stable-sensitive-owner@worklaw-test.test|Stable Sensitive Owner|Stable Sensitive Org"
  "stable-sensitive-member@worklaw-test.test|Stable Sensitive Member|Stable Sensitive Member Org"
  "stable-crud@worklaw-test.test|Stable Crud Owner|Stable Crud Org"
  "stable-isolation-a@worklaw-test.test|Stable Isolation Owner A|Stable Isolation Org A"
  "stable-isolation-b@worklaw-test.test|Stable Isolation Owner B|Stable Isolation Org B"
  "stable-orgimmut-a@worklaw-test.test|Stable OrgImmut Owner A|Stable OrgImmut Org A"
  "stable-orgimmut-b@worklaw-test.test|Stable OrgImmut Owner B|Stable OrgImmut Org B"
  "stable-legalrules@worklaw-test.test|Stable LegalRules User|Stable LegalRules Org"
  "stable-legalvis@worklaw-test.test|Stable LegalVis User|Stable LegalVis Org"
)
