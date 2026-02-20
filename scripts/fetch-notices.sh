#!/usr/bin/env bash
# scripts/fetch-notices.sh
#
# Downloads attribution notices for third-party software and aggregates them
# into a NOTICES file in each chart directory.
#
# Five types of license obligations are handled:
#
#   Apache 2.0 §4(d) — reproduce the upstream NOTICE file (where one exists).
#
#   MIT / ISC / Blue Oak — preserve the copyright and permission notice.
#
#   BSD-2/3-Clause / EDL-1.0 — reproduce the copyright notice in binary
#     distributions; EDL-1.0 (used by RDF4J) is Eclipse's variant of BSD-3.
#
#   EPL-1.0 / EPL-2.0 — copyleft; must include:
#     (a) the copyright notice, (b) the full EPL license text, and
#     (c) a pointer to where the source code can be obtained.
#     For dual-licensed components (logback: EPL-1.0 OR LGPL-2.1;
#     H2: MPL-2.0 OR EPL-1.0) we choose EPL-1.0 to avoid LGPL's
#     "allow-replacement" requirement and MPL's file-level copyleft.
#
#   LGPL-2.1 / MPL-2.0 — documented as alternatives; EPL-1.0 is chosen
#     for all dual-licensed components (see above).
#
# Run this script whenever third-party dependencies change.
# Commit the generated NOTICES files to source control — they are included
# in the Helm chart package (.tgz) and therefore distributed to end users.
#
# Usage:
#   ./scripts/fetch-notices.sh          # fetch and write NOTICES files
#   ./scripts/fetch-notices.sh --check  # verify URLs (no writes)
#
# Requirements: curl, python3, unzip

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
CHARTS_DIR="${REPO_ROOT}/charts"
TMP_DIR="${REPO_ROOT}/.tmp-notices"
CHECK_ONLY=false

if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=true
  echo "CHECK mode: verifying URLs (not writing files)."
fi

# ANSI colors (disabled if not a terminal)
if [[ -t 1 ]]; then
  YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'
else
  YELLOW=''; GREEN=''; BOLD=''; NC=''
fi

SEP_EQ="$(printf '%0.s=' {1..70})"
SEP_DA="$(printf '%0.s-' {1..70})"

mkdir -p "${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}"' EXIT

WARNINGS=0
FETCHED=0

###############################################################################
# Helpers
###############################################################################

write_header() {
  local output_file="$1"
  local chart_name="$2"
  cat > "${output_file}" <<EOF
THIRD-PARTY NOTICES FOR: ${chart_name}
${SEP_EQ}

This file satisfies the attribution obligations of the open-source licenses
used by third-party software bundled in, or deployed by, the ${chart_name}
Helm chart:

  - Apache 2.0 §4(d): upstream NOTICE file content is reproduced below.
  - MIT / ISC / Blue Oak: copyright notices are reproduced below.
  - BSD-2/3-Clause / EDL-1.0: copyright notices are reproduced below.
  - EPL-1.0 / EPL-2.0: full license text + copyright + source URL included.
    (For dual-licensed components we elect EPL-1.0 over LGPL-2.1 / MPL-2.0.)

See LICENSES-THIRD-PARTY.md for the complete dependency list, license types,
and links to the full license texts.

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
${SEP_EQ}
EOF
}

write_section() {
  local output_file="$1"
  local title="$2"
  printf '\n\n%s\n%s\n%s\n' "${SEP_EQ}" "${title}" "${SEP_EQ}" >> "${output_file}"
}

safe_name() {
  echo "${1}" | tr '/: *()' '_____'
}

# fetch_notice <label> <url> <output_file>
# Downloads an Apache 2.0 NOTICE file and appends it to output_file.
# Non-fatal if missing: not every Apache 2.0 project ships a NOTICE file.
fetch_notice() {
  local label="$1"
  local url="$2"
  local output_file="$3"
  local tmp_file="${TMP_DIR}/$(safe_name "${label}").NOTICE"

  printf "  %-58s" "${label}"
  if curl -fsSL --max-time 30 "${url}" -o "${tmp_file}" 2>/dev/null \
      && [[ -s "${tmp_file}" ]]; then
    if [[ "${CHECK_ONLY}" == "false" ]]; then
      printf '\n\n%s\nNOTICE: %s\nSource: %s\n%s\n\n' \
        "${SEP_DA}" "${label}" "${url}" "${SEP_DA}" >> "${output_file}"
      cat "${tmp_file}" >> "${output_file}"
    fi
    printf "${GREEN}OK${NC}\n"
    FETCHED=$(( FETCHED + 1 ))
  else
    printf "${YELLOW}NOT FOUND${NC}\n"
    printf "         URL: %s\n" "${url}"
    WARNINGS=$(( WARNINGS + 1 ))
  fi
}

# fetch_notice_from_jar <label> <jar_url> <path_in_jar> <output_file>
# Downloads a Maven JAR and extracts an embedded NOTICE file from it.
# Use for projects that embed NOTICE in the JAR but not in their GitHub root.
fetch_notice_from_jar() {
  local label="$1"
  local jar_url="$2"
  local notice_path="$3"
  local output_file="$4"
  local sn; sn="$(safe_name "${label}")"
  local jar_file="${TMP_DIR}/${sn}.jar"
  local tmp_file="${TMP_DIR}/${sn}.NOTICE"

  printf "  %-58s" "${label}"
  if ! command -v unzip &>/dev/null; then
    printf "${YELLOW}SKIP (unzip not installed)${NC}\n"
    WARNINGS=$(( WARNINGS + 1 ))
    return
  fi
  if curl -fsSL --max-time 60 "${jar_url}" -o "${jar_file}" 2>/dev/null \
      && unzip -p "${jar_file}" "${notice_path}" > "${tmp_file}" 2>/dev/null \
      && [[ -s "${tmp_file}" ]]; then
    if [[ "${CHECK_ONLY}" == "false" ]]; then
      printf '\n\n%s\nNOTICE: %s\nSource: %s!%s\n%s\n\n' \
        "${SEP_DA}" "${label}" "${jar_url}" "${notice_path}" "${SEP_DA}" >> "${output_file}"
      cat "${tmp_file}" >> "${output_file}"
    fi
    printf "${GREEN}OK (from JAR)${NC}\n"
    FETCHED=$(( FETCHED + 1 ))
  else
    printf "${YELLOW}NOT FOUND${NC}\n"
    printf "         JAR: %s\n" "${jar_url}"
    WARNINGS=$(( WARNINGS + 1 ))
  fi
}

# fetch_copyright <label> <license_type> <license_url> <output_file>
# Downloads a LICENSE file and extracts its copyright notice.
# Used for MIT and BSD-2/3-Clause dependencies.
fetch_copyright() {
  local label="$1"
  local license_type="$2"
  local url="$3"
  local output_file="$4"
  local tmp_file="${TMP_DIR}/$(safe_name "${label}").LICENSE"

  printf "  %-58s" "${label}"
  if curl -fsSL --max-time 30 "${url}" -o "${tmp_file}" 2>/dev/null \
      && [[ -s "${tmp_file}" ]]; then
    if [[ "${CHECK_ONLY}" == "false" ]]; then
      # Extract copyright lines (case-insensitive). python3 is used for
      # reliability across different grep flavours.
      local copyright_lines
      copyright_lines="$(python3 - "${tmp_file}" <<'PYEOF'
import re, sys
text = open(sys.argv[1], errors="replace").read()
lines = text.splitlines()
result = []
for line in lines[:40]:   # copyright is always near the top
    if re.search(r"copyright|©|\(c\)", line, re.IGNORECASE):
        result.append(line)
print("\n".join(result) if result else "(see source URL for copyright holder)")
PYEOF
)"
      printf '\n\n%s\nCOPYRIGHT: %s (%s)\nSource: %s\n%s\n%s\n' \
        "${SEP_DA}" "${label}" "${license_type}" "${url}" "${SEP_DA}" \
        "${copyright_lines}" >> "${output_file}"
    fi
    printf "${GREEN}OK${NC}\n"
    FETCHED=$(( FETCHED + 1 ))
  else
    printf "${YELLOW}NOT FOUND${NC}\n"
    printf "         URL: %s\n" "${url}"
    WARNINGS=$(( WARNINGS + 1 ))
  fi
}

# fetch_copyleft <label> <license_name> <license_url> <source_url> <output_file> [extra_copyright]
# Downloads a copyleft license file (EPL-1.0, EPL-2.0, LGPL-2.1) and includes:
#   - the copyright notice(s) extracted from the file
#   - an optional extra_copyright line (useful when the LICENSE file is the
#     standard FSF text and does not contain the software's own copyright)
#   - the full license text (required by EPL §4 / LGPL §6 / MPL §3.4)
#   - a pointer to the upstream source code repository
fetch_copyleft() {
  local label="$1"
  local license_name="$2"
  local license_url="$3"
  local source_url="$4"
  local output_file="$5"
  local extra_copyright="${6:-}"
  local tmp_file="${TMP_DIR}/$(safe_name "${label}").LICENSE"

  printf "  %-58s" "${label}"
  if curl -fsSL --max-time 30 "${license_url}" -o "${tmp_file}" 2>/dev/null \
      && [[ -s "${tmp_file}" ]]; then
    if [[ "${CHECK_ONLY}" == "false" ]]; then
      local copyright_lines
      copyright_lines="$(python3 - "${tmp_file}" <<'PYEOF'
import re, sys
text = open(sys.argv[1], errors="replace").read()
result = []
for line in text.splitlines()[:40]:
    if re.search(r"copyright|©|\(c\)", line, re.IGNORECASE):
        result.append(line)
print("\n".join(result) if result else "(see license text below)")
PYEOF
)"
      local all_copyright="${copyright_lines}"
      [[ -n "${extra_copyright}" ]] && all_copyright="${extra_copyright}"$'\n'"${all_copyright}"
      printf '\n\n%s\nCOPYLEFT: %s (%s)\nSource code: %s\nLicense file: %s\n%s\n%s\n\nFull license text:\n\n' \
        "${SEP_DA}" "${label}" "${license_name}" "${source_url}" \
        "${license_url}" "${SEP_DA}" "${all_copyright}" >> "${output_file}"
      cat "${tmp_file}" >> "${output_file}"
    fi
    printf "${GREEN}OK${NC}\n"
    FETCHED=$(( FETCHED + 1 ))
  else
    printf "${YELLOW}NOT FOUND${NC}\n"
    printf "         URL: %s\n" "${license_url}"
    WARNINGS=$(( WARNINGS + 1 ))
  fi
}

###############################################################################
# CHART: ontopic-server
###############################################################################

CHART="ontopic-server"
OUTPUT="${CHARTS_DIR}/${CHART}/NOTICES"
printf "\n${BOLD}[%s]${NC}\n" "${CHART}"
[[ "${CHECK_ONLY}" == "false" ]] && write_header "${OUTPUT}" "${CHART}"

# ---------------------------------------------------------------------------
# Section 1: Apache 2.0 NOTICE files
#
# Dependencies that do NOT ship a NOTICE file (no action required):
#   it.unibz.inf.ontop, com.google.guava, com.google.code.gson,
#   com.google.code.findbugs:jsr305, io.minio, org.springdoc:springdoc-openapi,
#   net.sourceforge.owlapi, eu.optique-project
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && write_section "${OUTPUT}" "SECTION 1: Apache 2.0 NOTICE Files"

# AWS SDK for Java v2 (software.amazon.awssdk:*)
fetch_notice "software.amazon.awssdk (AWS SDK for Java v2)" \
  "https://raw.githubusercontent.com/aws/aws-sdk-java-v2/master/NOTICE.txt" \
  "${OUTPUT}"

# Apache Commons RDF (org.apache.commons:commons-rdf-rdf4j)
fetch_notice "org.apache.commons:commons-rdf (Apache Commons RDF)" \
  "https://raw.githubusercontent.com/apache/commons-rdf/master/NOTICE" \
  "${OUTPUT}"

# Jackson Core (com.fasterxml.jackson.core:jackson-core) — NOTICE is in the JAR.
# Update the version number when upgrading the Jackson dependency.
fetch_notice_from_jar "com.fasterxml.jackson.core:jackson-core" \
  "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/2.18.2/jackson-core-2.18.2.jar" \
  "META-INF/NOTICE" \
  "${OUTPUT}"

fetch_notice_from_jar "com.fasterxml.jackson.core:jackson-core (FastDoubleParser)" \
  "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/2.18.2/jackson-core-2.18.2.jar" \
  "META-INF/FastDoubleParser-NOTICE" \
  "${OUTPUT}"

# Spring Boot — NOTICE build resource propagated into distributed JARs.
fetch_notice "org.springframework.boot (Spring Boot)" \
  "https://raw.githubusercontent.com/spring-projects/spring-boot/main/buildSrc/src/main/resources/org/springframework/boot/build/legal/NOTICE.txt" \
  "${OUTPUT}"

# ---------------------------------------------------------------------------
# Section 2: MIT / BSD-2-Clause Copyright Notices
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && {
  write_section "${OUTPUT}" "SECTION 2: MIT / BSD-2-Clause Copyright Notices"
  cat >> "${OUTPUT}" <<'EOF'

The notices below satisfy the copyright preservation requirement of the MIT
License and BSD-2-Clause License. Full license texts are available at the
URLs listed in LICENSES-THIRD-PARTY.md.
EOF
}

# org.slf4j:slf4j-api — MIT
fetch_copyright "org.slf4j:slf4j-api" "MIT" \
  "https://raw.githubusercontent.com/qos-ch/slf4j/master/LICENSE.txt" \
  "${OUTPUT}"

# org.postgresql:postgresql JDBC driver — BSD-2-Clause
fetch_copyright "org.postgresql:postgresql (pgjdbc)" "BSD-2-Clause" \
  "https://raw.githubusercontent.com/pgjdbc/pgjdbc/master/LICENSE" \
  "${OUTPUT}"

# com.moandjiezana.toml:toml4j — MIT
# NOTE: LICENSE.md exists in the repo but is inaccessible via raw.githubusercontent.com.
# Copyright (c) 2013 moandji.ezana — https://github.com/moandjiezana/toml4j
if [[ "${CHECK_ONLY}" == "false" ]]; then
  printf '\n\n%s\nCOPYRIGHT: com.moandjiezana.toml:toml4j (MIT)\nSource: https://github.com/moandjiezana/toml4j/blob/master/LICENSE.md\n%s\nCopyright (c) 2013 moandji.ezana\n' \
    "${SEP_DA}" "${SEP_DA}" >> "${OUTPUT}"
fi
printf "  %-58s${YELLOW}hardcoded${NC}\n" "com.moandjiezana.toml:toml4j (MIT)"
FETCHED=$(( FETCHED + 1 ))

# ---------------------------------------------------------------------------
# Section 3: EDL-1.0 Copyright Notices
# EDL-1.0 (Eclipse Distribution License) is Eclipse's variant of BSD-3-Clause.
# Compliance: preserve the copyright notice in binary distributions.
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && {
  write_section "${OUTPUT}" "SECTION 3: EDL-1.0 Copyright Notices (= BSD-3-Clause)"
  cat >> "${OUTPUT}" <<'EOF'

EDL-1.0 (Eclipse Distribution License 1.0) is Eclipse's variant of BSD-3-Clause.
The copyright notice below must be preserved in binary distributions.
Full license text: https://www.eclipse.org/org/documents/edl-v10.php
EOF
}

# org.eclipse.rdf4j:* — EDL-1.0
fetch_copyright "org.eclipse.rdf4j (Eclipse RDF4J)" "EDL-1.0" \
  "https://raw.githubusercontent.com/eclipse-rdf4j/rdf4j/main/LICENSE" \
  "${OUTPUT}"

# ---------------------------------------------------------------------------
# Section 4: EPL-1.0 Copyleft Notices (full license text included)
#
# ch.qos.logback is dual-licensed EPL-1.0 OR LGPL-2.1 — EPL-1.0 is chosen.
# com.h2database:h2 is dual-licensed MPL-2.0 OR EPL-1.0 — EPL-1.0 is chosen.
#
# junit:junit (EPL-1.0) and org.junit.vintage:junit-vintage-engine (EPL-2.0)
# are test-scope only and are NOT shipped with the Helm chart or Docker images.
#
# EPL-1.0 requires: (a) include the license text, (b) include copyright
# notices, (c) make source code available (satisfied by upstream URLs below).
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && {
  write_section "${OUTPUT}" "SECTION 4: EPL-1.0 Copyleft Notices"
  cat >> "${OUTPUT}" <<'EOF'

The Eclipse Public License (EPL) is a copyleft license. Recipients of software
under EPL must be able to obtain the source code of the EPL-covered components.
The source code for each component is available at the URL listed below.

  ch.qos.logback: dual EPL-1.0 OR LGPL-2.1 — EPL-1.0 elected.
  com.h2database:h2: dual MPL-2.0 OR EPL-1.0 — EPL-1.0 elected.
EOF
}

# ch.qos.logback:* — EPL-1.0 (chosen over LGPL-2.1)
# The LICENSE.txt in the logback repo contains the EPL-1.0 full text.
fetch_copyleft "ch.qos.logback (Logback)" "EPL-1.0 (elected over LGPL-2.1)" \
  "https://raw.githubusercontent.com/qos-ch/logback/master/LICENSE.txt" \
  "https://github.com/qos-ch/logback" \
  "${OUTPUT}"

# com.h2database:h2 — EPL-1.0 (chosen over MPL-2.0)
fetch_copyleft "com.h2database:h2" "EPL-1.0 (elected over MPL-2.0)" \
  "https://raw.githubusercontent.com/h2database/h2database/master/LICENSE.txt" \
  "https://github.com/h2database/h2database" \
  "${OUTPUT}"

# ---------------------------------------------------------------------------
# Section 5: JDBC Drivers shipped with ontopic-server
#
# Apache 2.0 with NOTICE:
#   Dremio (NOTICE at GitHub root), Presto (NOTICE embedded in JAR),
#   Snowflake (bundles FastDoubleParser-NOTICE in JAR)
#   Redshift (no NOTICE; LICENSE carries BSD-2 copyright — reproduced below)
#   Trino (no top-level NOTICE, internal okhttp3 only — no action required)
#   Amazon Athena (Apache-2.0; NOTICE fetched if present)
#
# MIT:
#   SQL Server mssql-jdbc — copyright notice
#
# LGPL-2.1-or-later (copyleft, full license text included):
#   MariaDB Connector/J
#
# Already covered in earlier sections (no duplication needed):
#   PostgreSQL JDBC → Section 2 (BSD-2-Clause, org.postgresql:postgresql)
#   H2              → Section 4 (EPL-1.0)
#
# Proprietary (no open-source attribution required):
#   Databricks JDBC → Databricks JDBC License
#   Oracle ojdbc11  → Oracle Free Use Terms and Conditions
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && {
  write_section "${OUTPUT}" "SECTION 5: JDBC Drivers shipped with ontopic-server"
  cat >> "${OUTPUT}" <<'EOF'

Notices for JDBC drivers bundled inside the ontopic-server Docker image.
Drivers already covered in earlier sections (PostgreSQL JDBC, H2) are omitted.
Proprietary drivers (Databricks, Oracle) carry no open-source notice obligation.
EOF
}

# Dremio JDBC (Apache 2.0) — NOTICE at repo root
fetch_notice "dremio-jdbc-driver (Dremio)" \
  "https://raw.githubusercontent.com/dremio/dremio-oss/master/NOTICE" \
  "${OUTPUT}"

# SQL Server mssql-jdbc (MIT) — copyright from LICENSE
fetch_copyright "com.microsoft.sqlserver:mssql-jdbc (SQL Server)" "MIT" \
  "https://raw.githubusercontent.com/microsoft/mssql-jdbc/master/LICENSE" \
  "${OUTPUT}"

# Snowflake JDBC (Apache 2.0) — no root NOTICE; bundles FastDoubleParser.
# Update the version below when upgrading the Snowflake JDBC dependency.
fetch_notice_from_jar "net.snowflake:snowflake-jdbc (FastDoubleParser)" \
  "https://repo1.maven.org/maven2/net/snowflake/snowflake-jdbc/3.26.0/snowflake-jdbc-3.26.0.jar" \
  "META-INF/FastDoubleParser-NOTICE" \
  "${OUTPUT}"

# Amazon Redshift JDBC (Apache 2.0 + BSD-2-Clause for PostgreSQL portions).
# No NOTICE file; BSD-2-Clause requires reproducing both copyright notices.
fetch_copyright "amazon-redshift-jdbc-driver (Redshift)" "Apache-2.0 + BSD-2-Clause" \
  "https://raw.githubusercontent.com/aws/amazon-redshift-jdbc-driver/master/LICENSE" \
  "${OUTPUT}"

# Amazon Athena JDBC (Apache 2.0) — NOTICE at repo root.
# Source: https://github.com/awslabs/aws-athena-query-federation
fetch_notice "AthenaJDBC42 (Amazon Athena JDBC)" \
  "https://raw.githubusercontent.com/awslabs/aws-athena-query-federation/master/NOTICE" \
  "${OUTPUT}"

# Presto JDBC (Apache 2.0) — NOTICE embedded in JAR at META-INF/NOTICE.
# Update the version below when upgrading the Presto JDBC dependency.
fetch_notice_from_jar "com.facebook.presto:presto-jdbc" \
  "https://repo1.maven.org/maven2/com/facebook/presto/presto-jdbc/0.293/presto-jdbc-0.293.jar" \
  "META-INF/NOTICE" \
  "${OUTPUT}"

# MariaDB Connector/J (LGPL-2.1-or-later) — copyleft; full license text included.
# The LICENSE file in the repo is the standard LGPL-2.1 text (FSF-authored).
# The software copyright is held by MariaDB Corporation Ab and contributors.
fetch_copyleft "mariadb-java-client (MariaDB Connector/J)" "LGPL-2.1-or-later" \
  "https://raw.githubusercontent.com/mariadb-corporation/mariadb-connector-j/main/LICENSE" \
  "https://github.com/mariadb-corporation/mariadb-connector-j" \
  "${OUTPUT}" \
  "Copyright (c) MariaDB Corporation Ab and contributors"

printf "  -> %s\n" "${OUTPUT}"

###############################################################################
# CHART: ontopic-suite
###############################################################################

CHART="ontopic-suite"
OUTPUT="${CHARTS_DIR}/${CHART}/NOTICES"
printf "\n${BOLD}[%s]${NC}\n" "${CHART}"
[[ "${CHECK_ONLY}" == "false" ]] && write_header "${OUTPUT}" "${CHART}"

# ---------------------------------------------------------------------------
# Section 1: Apache 2.0 NOTICE files
#
# Dependencies that do NOT ship a NOTICE file (no action required):
#   github.com/spf13/cobra, io.vertx, casbin, rxjs, tslib,
#   net.liftweb:lift-json, com.mchange:c3p0, kubernetes/kubectl
#
# EPL/LGPL/MPL dependencies are handled in Section 6 (see below):
#   ch.qos.logback (EPL-1.0 OR LGPL-2.1), com.h2database:h2 (MPL-2.0 OR EPL-1.0)
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && write_section "${OUTPUT}" "SECTION 1: Apache 2.0 NOTICE Files"

# Apache Jena (org.apache.jena:*) — process-server
fetch_notice "org.apache.jena (Apache Jena)" \
  "https://raw.githubusercontent.com/apache/jena/main/NOTICE" \
  "${OUTPUT}"

# circe (io.circe:*) — process-server; NOTICE attributes the Argonaut project
fetch_notice "io.circe (circe)" \
  "https://raw.githubusercontent.com/circe/circe/main/NOTICE" \
  "${OUTPUT}"

# ---------------------------------------------------------------------------
# Section 2: MIT Copyright Notices — Go (identity-service, gitea-manager)
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && {
  write_section "${OUTPUT}" "SECTION 2: MIT Copyright Notices — Go services"
  cat >> "${OUTPUT}" <<'EOF'

The notices below satisfy the copyright preservation requirement of the MIT
License. Full license texts are available at the URLs in LICENSES-THIRD-PARTY.md.
EOF
}

fetch_copyright "github.com/go-chi/chi/v5" "MIT" \
  "https://raw.githubusercontent.com/go-chi/chi/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "github.com/go-chi/render" "MIT" \
  "https://raw.githubusercontent.com/go-chi/render/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "github.com/lestrrat-go/jwx/v2" "MIT" \
  "https://raw.githubusercontent.com/lestrrat-go/jwx/main/LICENSE" \
  "${OUTPUT}"

fetch_copyright "github.com/fxamacker/cbor" "MIT" \
  "https://raw.githubusercontent.com/fxamacker/cbor/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "github.com/patrickmn/go-cache" "MIT" \
  "https://raw.githubusercontent.com/patrickmn/go-cache/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "github.com/spf13/viper" "MIT" \
  "https://raw.githubusercontent.com/spf13/viper/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "github.com/tidwall/buntdb" "MIT" \
  "https://raw.githubusercontent.com/tidwall/buntdb/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "go.uber.org/zap" "MIT" \
  "https://raw.githubusercontent.com/uber-go/zap/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "github.com/thanhpk/randstr" "MIT" \
  "https://raw.githubusercontent.com/thanhpk/randstr/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "code.gitea.io/sdk/gitea" "MIT" \
  "https://raw.githubusercontent.com/go-gitea/go-sdk/master/LICENSE" \
  "${OUTPUT}"

# ---------------------------------------------------------------------------
# Section 3: BSD-3-Clause Copyright Notices — Go (identity-service)
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && {
  write_section "${OUTPUT}" "SECTION 3: BSD-3-Clause Copyright Notices — Go services"
  cat >> "${OUTPUT}" <<'EOF'

The notices below satisfy BSD-3-Clause §2 (binary redistribution). The full
license conditions (clauses 1–3) and disclaimer apply to each; the complete
text is available at the URL in LICENSES-THIRD-PARTY.md.
EOF
}

fetch_copyright "github.com/spf13/pflag" "BSD-3-Clause" \
  "https://raw.githubusercontent.com/spf13/pflag/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "golang.org/x/crypto" "BSD-3-Clause" \
  "https://raw.githubusercontent.com/golang/crypto/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "golang.org/x/oauth2" "BSD-3-Clause" \
  "https://raw.githubusercontent.com/golang/oauth2/master/LICENSE" \
  "${OUTPUT}"

# ---------------------------------------------------------------------------
# Section 4: MIT Copyright Notices — Scala/JVM (process-server)
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && {
  write_section "${OUTPUT}" "SECTION 4: MIT Copyright Notices — process-server (Scala)"
  cat >> "${OUTPUT}" <<'EOF'

The notices below satisfy the copyright preservation requirement of the MIT
License for Scala/JVM dependencies used in process-server.
EOF
}

fetch_copyright "com.lihaoyi:requests-scala" "MIT" \
  "https://raw.githubusercontent.com/com-lihaoyi/requests-scala/master/LICENSE" \
  "${OUTPUT}"

# ---------------------------------------------------------------------------
# Section 5: MIT / ISC / Blue Oak / BSD Copyright Notices — Node.js services
#
# jszip is "MIT OR GPL-3.0-or-later" — MIT is elected.
# lru-cache uses Blue Oak Model License 1.0.0 (permissive, similar to MIT).
# node-cron uses ISC (functionally identical to BSD-2-Clause).
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && {
  write_section "${OUTPUT}" "SECTION 5: MIT / ISC / Blue Oak / BSD Copyright Notices — Node.js services"
  cat >> "${OUTPUT}" <<'EOF'

The notices below satisfy the copyright preservation requirement of the MIT,
ISC, Blue Oak 1.0.0, and BSD-2/3-Clause Licenses for Node.js dependencies.
  jszip: "MIT OR GPL-3.0-or-later" — MIT is elected.
EOF
}

# @angular/* — all Angular packages share the same Google LLC copyright
fetch_copyright "@angular/* (Angular)" "MIT" \
  "https://raw.githubusercontent.com/angular/angular/main/LICENSE" \
  "${OUTPUT}"

fetch_copyright "express" "MIT" \
  "https://raw.githubusercontent.com/expressjs/express/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "knex" "MIT" \
  "https://raw.githubusercontent.com/knex/knex/master/LICENSE" \
  "${OUTPUT}"

fetch_copyright "isomorphic-git" "MIT" \
  "https://raw.githubusercontent.com/isomorphic-git/isomorphic-git/main/LICENSE.md" \
  "${OUTPUT}"

fetch_copyright "yjs" "MIT" \
  "https://raw.githubusercontent.com/yjs/yjs/master/LICENSE" \
  "${OUTPUT}"

# jszip — MIT elected (over GPL-3.0-or-later)
fetch_copyright "jszip (MIT elected over GPL-3.0-or-later)" "MIT" \
  "https://raw.githubusercontent.com/Stuk/jszip/main/LICENSE.markdown" \
  "${OUTPUT}"

# lru-cache — Blue Oak Model License 1.0.0 (permissive)
fetch_copyright "lru-cache" "Blue Oak 1.0.0" \
  "https://raw.githubusercontent.com/isaacs/node-lru-cache/main/LICENSE.md" \
  "${OUTPUT}"

# node-cron — ISC (= BSD-2-Clause)
fetch_copyright "node-cron" "ISC" \
  "https://raw.githubusercontent.com/node-cron/node-cron/main/LICENSE.md" \
  "${OUTPUT}"

fetch_copyright "leaflet" "BSD-2-Clause" \
  "https://raw.githubusercontent.com/Leaflet/Leaflet/main/LICENSE" \
  "${OUTPUT}"

fetch_copyright "sqlite3 (node-sqlite3)" "BSD-3-Clause" \
  "https://raw.githubusercontent.com/TryGhost/node-sqlite3/master/LICENSE" \
  "${OUTPUT}"

# ---------------------------------------------------------------------------
# Section 6: EPL-1.0 Copyleft Notices — process-server (Scala)
#
# ch.qos.logback is dual-licensed EPL-1.0 OR LGPL-2.1 — EPL-1.0 is chosen.
# com.h2database:h2 is dual-licensed MPL-2.0 OR EPL-1.0 — EPL-1.0 is chosen.
# Full EPL-1.0 license text is included as required by EPL §4.
# Source code is available at the upstream repository URLs.
# ---------------------------------------------------------------------------
[[ "${CHECK_ONLY}" == "false" ]] && {
  write_section "${OUTPUT}" "SECTION 6: EPL-1.0 Copyleft Notices — process-server (Scala)"
  cat >> "${OUTPUT}" <<'EOF'

The Eclipse Public License (EPL) is a copyleft license. Recipients of software
under EPL must be able to obtain the source code of the EPL-covered components.
The source code for each component is available at the URL listed below.

  ch.qos.logback: dual EPL-1.0 OR LGPL-2.1 — EPL-1.0 elected.
  com.h2database:h2: dual MPL-2.0 OR EPL-1.0 — EPL-1.0 elected.
EOF
}

# ch.qos.logback:* — EPL-1.0 (chosen over LGPL-2.1)
fetch_copyleft "ch.qos.logback (Logback)" "EPL-1.0 (elected over LGPL-2.1)" \
  "https://raw.githubusercontent.com/qos-ch/logback/master/LICENSE.txt" \
  "https://github.com/qos-ch/logback" \
  "${OUTPUT}"

# com.h2database:h2 — EPL-1.0 (chosen over MPL-2.0)
fetch_copyleft "com.h2database:h2" "EPL-1.0 (elected over MPL-2.0)" \
  "https://raw.githubusercontent.com/h2database/h2database/master/LICENSE.txt" \
  "https://github.com/h2database/h2database" \
  "${OUTPUT}"

printf "  -> %s\n" "${OUTPUT}"

###############################################################################
# CHART: postgresql
#
# The PostgreSQL License is a permissive BSD-like license. It requires
# retaining the copyright notice in source/binary distributions.
###############################################################################

CHART="postgresql"
OUTPUT="${CHARTS_DIR}/${CHART}/NOTICES"
printf "\n${BOLD}[%s]${NC}\n" "${CHART}"
[[ "${CHECK_ONLY}" == "false" ]] && write_header "${OUTPUT}" "${CHART}"
[[ "${CHECK_ONLY}" == "false" ]] && write_section "${OUTPUT}" "PostgreSQL License Copyright Notice"

fetch_copyright "PostgreSQL" "PostgreSQL License (BSD-like)" \
  "https://raw.githubusercontent.com/postgres/postgres/master/COPYRIGHT" \
  "${OUTPUT}"

printf "  -> %s\n" "${OUTPUT}"

###############################################################################
# Summary
###############################################################################

printf "\n"
if [[ ${WARNINGS} -gt 0 ]]; then
  printf "${YELLOW}Done — %d fetched, %d warning(s).${NC}\n" "${FETCHED}" "${WARNINGS}"
  printf "Review warnings above. For Apache 2.0 dependencies with no NOTICE\n"
  printf "file, no further action is required under APL-2.0 §4(d).\n"
else
  printf "${GREEN}Done — all %d entries fetched successfully.${NC}\n" "${FETCHED}"
fi
