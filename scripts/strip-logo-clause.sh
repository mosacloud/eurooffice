#!/bin/bash
# Strip AGPL Section 7(b) trademark clause from all source files.
#
# Per FSF guidance, downstream recipients may remove Section 7(b) additional
# requirements that mandate retaining the original product logo.
# See: https://www.fsf.org/news/fsf-submits-amicus-brief-in-neo4j-v-suhy
#
# Removes these three lines from license headers:
#   * Pursuant to Section 7(b) of the License you must retain the original Product
#   * logo when distributing the program. Pursuant to Section 7(e) we decline to
#   * grant you any rights under trademark law for use of our trademarks.
#
# Searches recursively through: web-apps/, sdkjs/, core/, server/, fork/
# Skips: node_modules/, vendor/
# File types: js, less, css, html, htm, py, sh, json, ts, cpp, h, c
#
# Usage:
#   From the project root (host):
#     ./fork/scripts/strip-logo-clause.sh
#
#   With a custom root directory:
#     ./fork/scripts/strip-logo-clause.sh /path/to/euro-office
#
#   From inside the Docker container (via Makefile):
#     make strip-logo-clause
#
#   Run after upstream merges to remove any re-introduced clauses.

ROOT_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"

echo "Stripping AGPL Section 7(b) trademark clause from: $ROOT_DIR"

find "$ROOT_DIR" -type f \( -name "*.js" -o -name "*.less" -o -name "*.css" \
    -o -name "*.html" -o -name "*.htm" -o -name "*.py" -o -name "*.sh" \
    -o -name "*.json" -o -name "*.ts" -o -name "*.cpp" -o -name "*.h" \
    -o -name "*.c" \) \
    ! -path "*/node_modules/*" ! -path "*/vendor/*" \
    -exec sed -i'' '/Pursuant to Section 7(b)/,/grant you any rights under trademark law/d' {} +

echo "Done."
