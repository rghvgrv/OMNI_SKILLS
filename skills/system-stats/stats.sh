#!/usr/bin/env bash
# stats.sh — cross-OS system snapshot. Linux, macOS, Windows (Git Bash/MSYS/Cygwin).
# Override OS via OMNI_FORCE_OS for testing.
set -u

OS="${OMNI_FORCE_OS:-${OSTYPE:-unknown}}"

case "$OS" in
  linux*|linux-gnu*) KIND=linux ;;
  darwin*) KIND=macos ;;
  msys*|cygwin*|mingw*|win32) KIND=windows ;;
  *) echo "stats.sh: unsupported OS: $OS" >&2; exit 2 ;;
esac

print_line() { printf '%s\n' "$1"; }

ps_get() {
  # Run a one-line PS expression and strip CR.
  powershell.exe -NoProfile -Command "$1" 2>/dev/null | tr -d '\r' | head -n1
}

HAS_PS=0
command -v powershell.exe >/dev/null 2>&1 && HAS_PS=1

# --- OS name ---
OS_NAME=""
if [ "$KIND" = "linux" ]; then
  if [ -r /etc/os-release ]; then
    PRETTY_NAME=""
    . /etc/os-release 2>/dev/null || true
    OS_NAME="${PRETTY_NAME:-Linux}"
  else
    OS_NAME="Linux"
  fi
elif [ "$KIND" = "macos" ]; then
  ver="$(sw_vers -productVersion 2>/dev/null || echo)"
  OS_NAME="macOS $ver"
elif [ "$KIND" = "windows" ]; then
  if [ "$HAS_PS" = "1" ]; then
    OS_NAME="$(ps_get '(Get-CimInstance Win32_OperatingSystem).Caption')"
  fi
  OS_NAME="${OS_NAME:-Windows}"
fi

HOST="$(hostname 2>/dev/null || echo unknown)"

# --- CPU ---
CPU=""
CORES=""
if [ "$KIND" = "linux" ]; then
  CPU="$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null | sed 's/^[[:space:]]*//')"
  CORES="$(nproc 2>/dev/null || echo '?')"
elif [ "$KIND" = "macos" ]; then
  CPU="$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
  CORES="$(sysctl -n hw.ncpu 2>/dev/null || echo '?')"
elif [ "$KIND" = "windows" ]; then
  if [ "$HAS_PS" = "1" ]; then
    CPU="$(ps_get '(Get-CimInstance Win32_Processor).Name')"
    CORES="$(ps_get '(Get-CimInstance Win32_Processor).NumberOfLogicalProcessors')"
  fi
fi
CPU="${CPU:-unknown}"
CORES="${CORES:-?}"

# --- Memory ---
MEM_LINE=""
if [ "$KIND" = "linux" ]; then
  T_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  A_KB="$(awk '/MemAvailable/ {print $2}' /proc/meminfo)"
  U_KB=$(( T_KB - A_KB ))
  MEM_LINE="$(( U_KB / 1024 )) MB used / $(( T_KB / 1024 )) MB total"
elif [ "$KIND" = "macos" ]; then
  PAGE=$(sysctl -n hw.pagesize)
  TOTAL_B=$(sysctl -n hw.memsize)
  T_MB=$(( TOTAL_B / 1048576 ))
  PAGES_USED=$(vm_stat | awk '/Pages active|Pages wired down|Pages occupied/ {gsub(/\./,""); s+=$NF} END {print s}')
  U_MB=$(( PAGES_USED * PAGE / 1048576 ))
  MEM_LINE="${U_MB} MB used / ${T_MB} MB total"
elif [ "$KIND" = "windows" ]; then
  if [ "$HAS_PS" = "1" ]; then
    pair="$(ps_get '$o=Get-CimInstance Win32_OperatingSystem; "{0} {1}" -f $o.FreePhysicalMemory,$o.TotalVisibleMemorySize')"
    F_KB="${pair% *}"
    T_KB="${pair#* }"
    if [ -n "$T_KB" ] && [ "$T_KB" -gt 0 ] 2>/dev/null; then
      U_KB=$(( T_KB - F_KB ))
      MEM_LINE="$(( U_KB / 1024 )) MB used / $(( T_KB / 1024 )) MB total"
    fi
  fi
fi
MEM_LINE="${MEM_LINE:-unknown MB}"

# --- Disk ---
DISK=""
target="/"
[ "$KIND" = "windows" ] && target="${SYSTEMDRIVE:-C:}/"
DISK="$(df -h "$target" 2>/dev/null | awk 'NR==2 {print $3" used / "$2" total ("$5" used)"}')"
[ -z "$DISK" ] && DISK="$(df -h / 2>/dev/null | awk 'NR==2 {print $3" used / "$2" total ("$5" used)"}')"
DISK="${DISK:-unknown 0% used}"

# --- Uptime ---
UP=""
if [ "$KIND" = "linux" ]; then
  UP="$(uptime -p 2>/dev/null || uptime)"
elif [ "$KIND" = "macos" ]; then
  UP="$(uptime | sed 's/^.*up //' | sed 's/, *[0-9]* user.*//')"
elif [ "$KIND" = "windows" ]; then
  if [ "$HAS_PS" = "1" ]; then
    UP="$(ps_get '$b=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime; $d=(Get-Date)-$b; "{0}d {1}h {2}m" -f $d.Days,$d.Hours,$d.Minutes')"
  fi
fi
UP="${UP:-unknown}"

print_line "OS: $OS_NAME"
print_line "Hostname: $HOST"
print_line "CPU: $CPU ($CORES cores)"
print_line "Memory: $MEM_LINE"
print_line "Disk: $DISK"
print_line "Uptime: $UP"
