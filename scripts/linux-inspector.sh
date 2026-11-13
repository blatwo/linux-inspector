#!/usr/bin/env bash
# Linux System & Service Inspector - read-only system information collector
# Version: 0.1.0
set -u
export LC_ALL=C
VERSION=0.1.0
OUTPUT=""

usage() {
  cat <<'HELP'
Usage: linux-inspector.sh [--output FILE] [--help] [--version]
  --output FILE  Save the report to FILE (default: stdout)
  --help         Show help
  --version      Show version
Collects read-only OS, CPU, kernel, GCC, libc, package managers, init, Python and Java information.
No sudo, network requests, package installation, system changes or secrets collection.
HELP
}
while (($#)); do
  case "$1" in
    --output) if (($# < 2)) || [[ -z "$2" ]]; then echo 'Missing output file' >&2; exit 2; fi; OUTPUT=$2; shift 2;;
    --help|-h) usage; exit 0;;
    --version) echo "$VERSION"; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2;;
  esac
done

has() { command -v "$1" >/dev/null 2>&1; }
first_line() { awk 'NR==1 {print; exit}'; }
section() { printf '\n===== %s =====\n' "$1"; }
value_or_na() { [[ -n "$1" ]] && printf '%s\n' "$1" || printf 'not found\n'; }

report() {
  local os_id='' os_like='' os_name='' os_version='' os_family='unknown'
  local rpm_count='unknown' dpkg_count='unknown' base='unknown' high='unknown'
  if [[ -r /etc/os-release ]]; then
    # Distribution-controlled configuration; do not evaluate it as shell code.
    os_id=$(sed -n 's/^ID=//p' /etc/os-release | first_line | tr -d '"')
    os_like=$(sed -n 's/^ID_LIKE=//p' /etc/os-release | first_line | tr -d '"')
    os_name=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | first_line | sed 's/^"//;s/"$//')
    os_version=$(sed -n 's/^VERSION_ID=//p' /etc/os-release | first_line | tr -d '"')
  fi
  section '1. OS'
  printf 'Name: %s\nID: %s\nID_LIKE: %s\nVERSION_ID: %s\n' "${os_name:-unknown}" "${os_id:-unknown}" "${os_like:-not specified}" "${os_version:-unknown}"

  section '2. CPU'
  if has uname; then printf 'Architecture: %s\n' "$(uname -m 2>/dev/null)"; else echo 'Architecture: not found'; fi
  if has lscpu; then
    lscpu 2>/dev/null | grep -E '^(Architecture|CPU\(s\)|On-line CPU\(s\) list|Model name|Socket\(s\)|Core\(s\) per socket|Thread\(s\) per core|NUMA node\(s\)|NUMA node[0-9]+ CPU\(s\)):' || true
  else echo 'lscpu: not found'; fi

  section '3. Kernel'
  if has uname; then uname -r; uname -a; else echo 'uname: not found'; fi

  section '4. GCC'
  if has gcc; then
    local gcc_info
    gcc_info=$(gcc --version 2>&1 | first_line)
    value_or_na "$gcc_info"
  else echo 'gcc: not found'; fi

  section '5. libc'
  if has getconf; then
    printf 'GNU libc (getconf): '
    value_or_na "$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
  else echo 'getconf: not found'; fi
  if has ldd; then
    printf 'ldd: '
    value_or_na "$(ldd --version 2>&1 | first_line)"
  else echo 'ldd: not found'; fi
  if has bash && has ldd; then
    local libc_path
    libc_path=$(ldd "$(command -v bash)" 2>/dev/null | awk '/libc\.so\.6[[:space:]]+=>/ {print $3; exit}')
    printf 'libc path (bash dependency): %s\n' "${libc_path:-not found}"
  fi
  echo 'Note: libc may be musl or another implementation; ldd output alone is not definitive.'

  section '6. Package managers'
  printf 'Available commands:'
  local cmd
  for cmd in rpm dpkg dnf yum apt apt-get zypper apk pacman; do
    if has "$cmd"; then printf ' %s' "$cmd"; fi
  done
  echo
  if has rpm; then
    local rpm_output
    if rpm_output=$(rpm -qa 2>/dev/null); then
      rpm_count=$(printf '%s\n' "$rpm_output" | awk 'NF {n++} END {print n+0}')
    fi
  fi
  if has dpkg-query; then
    local dpkg_output
    if dpkg_output=$(dpkg-query -W -f='${db:Status-Status}\n' 2>/dev/null); then
      dpkg_count=$(printf '%s\n' "$dpkg_output" | awk '$0=="installed" {n++} END {print n+0}')
    fi
  fi
  printf 'RPM installed: %s\nDPKG installed: %s\n' "$rpm_count" "$dpkg_count"
  local family_text=" ${os_id,,} ${os_like,,} "
  # Whole-word matching prevents false positives such as 'notdebian'.
  if [[ "$family_text" =~ (^|[[:space:]])(debian|ubuntu|deepin|uos)([[:space:]]|$) ]]; then
    os_family='Debian-like'
    base='dpkg (expected)'
    if has apt; then high='apt'; elif has apt-get; then high='apt-get'; fi
  elif [[ "$family_text" =~ (^|[[:space:]])(rhel|fedora|centos|rocky|almalinux|anolis|openeuler|kylin|asianux|suse|opensuse)([[:space:]]|$) ]]; then
    os_family='RPM-like'
    base='rpm (expected)'
    if has dnf; then high='dnf'; elif has yum; then high='yum'; elif has zypper; then high='zypper'; fi
  elif [[ "$family_text" =~ (^|[[:space:]])alpine([[:space:]]|$) ]]; then
    os_family='Alpine-like'; base='apk'; if has apk; then high='apk'; fi
  elif [[ "$family_text" =~ (^|[[:space:]])arch([[:space:]]|$) ]]; then
    os_family='Arch-like'; base='pacman'; if has pacman; then high='pacman'; fi
  elif [[ "$dpkg_count" =~ ^[0-9]+$ && "$rpm_count" =~ ^[0-9]+$ && "$dpkg_count" -gt 0 && "$rpm_count" -eq 0 ]] || [[ "$dpkg_count" =~ ^[0-9]+$ && "$dpkg_count" -gt 0 && "$rpm_count" == unknown ]]; then
    os_family='DPKG-based (inferred)'; base='dpkg'; if has apt; then high='apt'; elif has apt-get; then high='apt-get'; fi
  elif [[ "$rpm_count" =~ ^[0-9]+$ && "$rpm_count" -gt 0 && "$dpkg_count" == unknown ]] || [[ "$rpm_count" =~ ^[0-9]+$ && "$dpkg_count" =~ ^[0-9]+$ && "$rpm_count" -gt 0 && "$dpkg_count" -eq 0 ]]; then
    os_family='RPM-based (inferred)'; base='rpm'; if has dnf; then high='dnf'; elif has yum; then high='yum'; elif has zypper; then high='zypper'; fi
  fi
  printf 'Family: %s\nBase: %s\nHigh-level: %s\n' "$os_family" "$base" "$high"
  if has rpm && [[ "$os_family" == 'Debian-like' ]]; then echo 'Note: rpm command exists but does not imply RPM is the native package system.'; fi
  echo 'Note: OS family is a hint; installed tools and package databases must be checked before installation.'

  section '7. Init / service manager'
  if has ps; then printf 'PID 1: %s\n' "$(ps -p 1 -o comm= 2>/dev/null | first_line)"; else echo 'ps: not found'; fi
  if [[ -e /proc/1/exe ]] && has readlink; then printf 'PID 1 executable: %s\n' "$(readlink -f /proc/1/exe 2>/dev/null)"; fi
  if has systemctl; then printf 'systemctl: %s\n' "$(systemctl --version 2>/dev/null | first_line)"; else echo 'systemctl: not found'; fi
  echo 'Note: systemctl installed does not guarantee systemd is PID 1.'

  section '8. Python'
  for cmd in python python3; do
    if has "$cmd"; then
      printf '%s: %s\n' "$cmd" "$("$cmd" --version 2>&1 | first_line)"
    else printf '%s: not found\n' "$cmd"; fi
  done

  section '9. Java / JDK'
  if has java; then
    local java_info
    java_info=$(java -version 2>&1 | first_line)
    printf 'java: %s\n' "${java_info:-not found}"
  else echo 'java: not found'; fi
  if has javac; then
    printf 'javac: %s\n' "$(javac -version 2>&1 | first_line)"
  else echo 'javac: not found (JRE-only or JDK not in PATH)'; fi
  echo 'Note: java/javac versions reflect PATH, not necessarily every installed JDK.'
  section '10. Summary'
  printf 'OS: %s | ID_LIKE: %s\n' "${os_name:-unknown}" "${os_like:-not specified}"
  printf 'Architecture: %s | Kernel: %s\n' "$(uname -m 2>/dev/null || echo unknown)" "$(uname -r 2>/dev/null || echo unknown)"
  printf 'Package family: %s | Base: %s | High-level: %s\n' "$os_family" "$base" "$high"
}

if [[ -n "$OUTPUT" ]]; then
  if ! report > "$OUTPUT"; then echo "Failed writing report: $OUTPUT" >&2; exit 1; fi
  printf 'Report saved: %s\n' "$OUTPUT"
else
  report
fi
