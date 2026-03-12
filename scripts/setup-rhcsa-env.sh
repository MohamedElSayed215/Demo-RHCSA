#!/bin/bash
# ==============================================
# RHCSA Lab Environment Setup Script
# Runs once at container startup
# ==============================================

set -e

echo "🔧 Setting up RHCSA practice environment..."

# ── Users & Groups ──
groupadd admin 2>/dev/null || true
groupadd production 2>/dev/null || true

useradd -m -s /bin/bash harry 2>/dev/null || true
useradd -m -s /bin/bash natasha 2>/dev/null || true
useradd -m -s /sbin/nologin sarah 2>/dev/null || true
useradd -m -s /bin/bash student 2>/dev/null || true
useradd -m -s /bin/bash alies 2>/dev/null || true

# Add to groups
usermod -aG admin harry 2>/dev/null || true
usermod -aG admin natasha 2>/dev/null || true

# Passwords
echo "harry:password" | chpasswd 2>/dev/null || true
echo "natasha:password" | chpasswd 2>/dev/null || true
echo "sarah:password" | chpasswd 2>/dev/null || true
echo "student:redhat" | chpasswd 2>/dev/null || true
echo "root:redhat" | chpasswd 2>/dev/null || true

# ── Directory Structure ──
mkdir -p /var/www/html
mkdir -p /var/tmp/testfiles
mkdir -p /user-homes/production5
mkdir -p /opt/files
mkdir -p /opt/processed
mkdir -p /mnt/database

# Create test files
echo "<h1>RHCSA Lab Web Server</h1>" > /var/www/html/index.html
echo "test content" > /var/www/html/test.html

# Create files owned by sarah for find task
touch /home/sarah/file1.txt
touch /home/sarah/document.txt
touch /tmp/sarah_temp.txt
chown sarah:sarah /home/sarah/file1.txt /home/sarah/document.txt
chown sarah:sarah /tmp/sarah_temp.txt 2>/dev/null || true

# Production5 NFS simulation
mkdir -p /user-homes/production5
echo "This is production5 home directory" > /user-homes/production5/readme.txt

# ── Fake /etc/yum.repos.d ──
mkdir -p /etc/yum.repos.d

# ── Fake systemd-like scripts ──
mkdir -p /etc/chrony
cat > /etc/chrony/chrony.conf << 'EOF'
# Chrony configuration
pool 2.rhel.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF

# ── Cron directories ──
mkdir -p /var/spool/cron/crontabs
touch /var/spool/cron/crontabs/harry
chown harry:crontab /var/spool/cron/crontabs/harry 2>/dev/null || true

# ── sudoers setup ──
mkdir -p /etc/sudoers.d
echo "student ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/student
chmod 440 /etc/sudoers.d/student

# ── Fake login.defs ──
if [ -f /etc/login.defs ]; then
  # Already exists on Ubuntu
  true
else
  cat > /etc/login.defs << 'EOF'
PASS_MAX_DAYS   99999
PASS_MIN_DAYS   0
PASS_WARN_AGE   7
UID_MIN         1000
UID_MAX         60000
GID_MIN         1000
GID_MAX         60000
EOF
fi

# ── Custom commands for RHCSA simulation ──

# nmcli mock
cat > /usr/local/bin/nmcli << 'NMCLI'
#!/bin/bash
echo "⚡ [nmcli] NetworkManager CLI"
case "$*" in
  *"con show"*)
    echo "NAME         UUID                                  TYPE      DEVICE"
    echo "System eth0  abcd-1234-5678-efgh  ethernet  eth0  "
    ;;
  *"con mod"*)
    echo "✓ Connection modified successfully."
    ;;
  *"con up"*)
    echo "✓ Connection 'System eth0' successfully activated."
    ;;
  *"general hostname"*)
    echo "✓ Hostname set."
    ;;
  *)
    echo "NetworkManager CLI — use: nmcli con show | mod | up"
    ;;
esac
NMCLI
chmod +x /usr/local/bin/nmcli

# hostnamectl mock
cat > /usr/local/bin/hostnamectl << 'HCT'
#!/bin/bash
HOSTNAME_FILE="/tmp/lab-hostname"
case "$1" in
  "set-hostname")
    echo "$2" > "$HOSTNAME_FILE"
    echo "✓ Hostname set to: $2"
    ;;
  "status"|"")
    HN=$(cat "$HOSTNAME_FILE" 2>/dev/null || hostname)
    echo "   Static hostname: $HN"
    echo "         Icon name: computer-vm"
    echo "           Chassis: vm"
    echo "  Operating System: Red Hat Enterprise Linux 9"
    echo "       CPE OS Name: cpe:/o:redhat:enterprise_linux:9"
    echo "            Kernel: Linux 5.14.0"
    echo "      Architecture: x86-64"
    ;;
  *)
    echo "Usage: hostnamectl set-hostname <name> | status"
    ;;
esac
HCT
chmod +x /usr/local/bin/hostnamectl

# semanage mock
cat > /usr/local/bin/semanage << 'SEM'
#!/bin/bash
echo "⚡ [SELinux] semanage — Security management"
case "$*" in
  *"port -a"*)
    PORT=$(echo "$*" | grep -oP '\d{2,5}' | head -1)
    echo "✓ SELinux: Port $PORT added to http_port_t"
    echo "✓ Policy saved."
    ;;
  *"port -l"*)
    echo "http_port_t    tcp    80, 81, 82, 443, 488, 8008, 8009, 8443, 9000"
    echo "ssh_port_t     tcp    22"
    ;;
  *"fcontext"*)
    echo "✓ File context policy updated."
    ;;
  *)
    echo "Usage: semanage port -a -t http_port_t -p tcp <port>"
    ;;
esac
SEM
chmod +x /usr/local/bin/semanage

# restorecon mock
cat > /usr/local/bin/restorecon << 'RST'
#!/bin/bash
echo "✓ restorecon: Relabeling $@ ..."
echo "✓ SELinux context restored successfully."
RST
chmod +x /usr/local/bin/restorecon

# getenforce mock
cat > /usr/local/bin/getenforce << 'GE'
#!/bin/bash
echo "Enforcing"
GE
chmod +x /usr/local/bin/getenforce

# setenforce mock
cat > /usr/local/bin/setenforce << 'SE'
#!/bin/bash
if [ "$1" = "0" ]; then
  echo "⚠️  WARNING: Disabling SELinux is NOT recommended in RHCSA exam!"
  echo "⚠️  Use semanage to allow specific ports/contexts instead."
else
  echo "✓ SELinux set to Enforcing mode."
fi
SE
chmod +x /usr/local/bin/setenforce

# systemctl mock (wraps real systemctl if available, otherwise simulates)
if ! command -v systemctl &>/dev/null; then
cat > /usr/local/bin/systemctl << 'SCT'
#!/bin/bash
ACTION="$1"; SERVICE="$2"
echo "⚡ [systemd] systemctl $ACTION $SERVICE"
case "$ACTION" in
  "enable"|"start"|"enable --now")
    echo "✓ Created symlink → $SERVICE.service"
    echo "✓ $SERVICE.service started successfully."
    ;;
  "status")
    echo "● $SERVICE.service"
    echo "   Loaded: loaded"
    echo "   Active: active (running) since $(date)"
    ;;
  "daemon-reload")
    echo "✓ Systemd daemon reloaded."
    ;;
  "disable"|"stop")
    echo "✓ $SERVICE.service stopped/disabled."
    ;;
  *)
    echo "Usage: systemctl [enable|start|stop|status|daemon-reload] <service>"
    ;;
esac
SCT
chmod +x /usr/local/bin/systemctl
fi

# firewall-cmd mock
cat > /usr/local/bin/firewall-cmd << 'FW'
#!/bin/bash
echo "⚡ [firewalld] firewall-cmd $@"
case "$*" in
  *"--permanent"*)
    PORT=$(echo "$*" | grep -oP '\d+/tcp' | head -1)
    echo "✓ Firewall rule added permanently${PORT:+ for $PORT}."
    ;;
  *"--reload"*)
    echo "✓ Firewall rules reloaded."
    ;;
  *"--list"*)
    echo "ports: 22/tcp 80/tcp 82/tcp 443/tcp"
    ;;
  *)
    echo "success"
    ;;
esac
FW
chmod +x /usr/local/bin/firewall-cmd

# chronyc mock
cat > /usr/local/bin/chronyc << 'CHR'
#!/bin/bash
case "$*" in
  "sources"|"sources -v")
    echo "210 Number of sources = 1"
    echo ""
    echo "MS Name/IP address         Stratum Poll Reach LastRx Last sample"
    echo "==============================================================================="
    echo "^* classroom.example.com        3  10   377   17m  +1234us[+1234us] +/-   20ms"
    ;;
  "tracking")
    echo "Reference ID    : C0A8FE01 (classroom.example.com)"
    echo "Stratum         : 4"
    echo "System time     : 0.000123456 seconds fast of NTP time"
    ;;
  *)
    echo "chronyc — chrony control program"
    ;;
esac
CHR
chmod +x /usr/local/bin/chronyc

# tuned-adm mock
cat > /usr/local/bin/tuned-adm << 'TND'
#!/bin/bash
PROFILE_FILE="/tmp/lab-tuned-profile"
case "$1" in
  "recommend")
    echo "virtual-guest"
    ;;
  "profile")
    echo "$2" > "$PROFILE_FILE"
    echo "✓ Switching to profile '$2'"
    echo "✓ Tuned profile '$2' applied."
    ;;
  "active")
    PROF=$(cat "$PROFILE_FILE" 2>/dev/null || echo "balanced")
    echo "Current active profile: $PROF"
    ;;
  "list")
    echo "Available profiles:"
    echo "- balanced"
    echo "- desktop"
    echo "- latency-performance"
    echo "- network-latency"
    echo "- throughput-performance"
    echo "- virtual-guest"
    echo "- virtual-host"
    ;;
  *)
    echo "Usage: tuned-adm [recommend|profile <name>|active|list]"
    ;;
esac
TND
chmod +x /usr/local/bin/tuned-adm

# podman mock
cat > /usr/local/bin/podman << 'PDM'
#!/bin/bash
echo "⚡ [Podman] $@"
case "$1" in
  "login")
    echo "Login Succeeded!"
    ;;
  "build")
    NAME=$(echo "$@" | grep -oP '(?<=-t )\S+' | head -1)
    echo "STEP 1/5: FROM registry.access.redhat.com/ubi9:latest"
    echo "STEP 2/5: RUN dnf install -y ..."
    echo "STEP 3/5: COPY . ."
    sleep 1
    echo "STEP 4/5: RUN chmod +x /entrypoint.sh"
    echo "STEP 5/5: CMD [\"/entrypoint.sh\"]"
    echo "Successfully built image: localhost/${NAME:-monitor}:latest"
    ;;
  "run")
    NAME=$(echo "$@" | grep -oP '(?<=--name )\S+' | head -1)
    echo "✓ Container '${NAME:-container}' started."
    echo "$(cat /proc/sys/kernel/random/uuid)"
    ;;
  "images")
    echo "REPOSITORY              TAG       IMAGE ID       CREATED        SIZE"
    echo "localhost/monitor       latest    a1b2c3d4e5f6   2 minutes ago  215 MB"
    ;;
  "generate")
    echo "✓ Generating systemd service file..."
    mkdir -p /root/.config/systemd/user
    cat > /root/.config/systemd/user/container-ascii2pdf.service << 'EOF'
[Unit]
Description=Podman container-ascii2pdf.service
[Service]
Restart=on-failure
ExecStart=/usr/bin/podman start ascii2pdf
ExecStop=/usr/bin/podman stop ascii2pdf
[Install]
WantedBy=default.target
EOF
    echo "✓ /root/.config/systemd/user/container-ascii2pdf.service"
    ;;
  "ps")
    echo "CONTAINER ID  IMAGE            COMMAND     CREATED       STATUS      NAMES"
    echo "abc123def456  localhost/monitor  /run.sh  1 minute ago  Up 1 min  ascii2pdf"
    ;;
  *)
    echo "Podman — manage containers, images, and pods"
    ;;
esac
PDM
chmod +x /usr/local/bin/podman

# loginctl mock
cat > /usr/local/bin/loginctl << 'LCT'
#!/bin/bash
case "$*" in
  *"enable-linger"*)
    USER="${@: -1}"
    echo "✓ Linger enabled for user: $USER"
    echo "✓ Services will persist after logout."
    ;;
  *)
    echo "loginctl — control the login manager"
    ;;
esac
LCT
chmod +x /usr/local/bin/loginctl

# pvcreate / vgcreate / lvcreate mocks (LVM)
for cmd in pvcreate vgcreate lvcreate lvextend lvresize; do
cat > /usr/local/bin/$cmd << LVCMD
#!/bin/bash
echo "⚡ [LVM] $cmd \$@"
case "$cmd" in
  pvcreate)
    echo "  Physical volume \"\$1\" successfully created."
    ;;
  vgcreate)
    VG=\$(echo "\$@" | awk '{print \$NF}')
    echo "  Volume group \"\$2\" successfully created."
    echo "  PE Size: \$(echo "\$@" | grep -oP '\\d+MiB' | head -1)"
    ;;
  lvcreate)
    LV=\$(echo "\$@" | grep -oP '(?<=-n )\\S+' | head-1)
    EXT=\$(echo "\$@" | grep -oP '(?<=-l )\\d+' | head -1)
    echo "  Logical volume \"\${LV:-database}\" created."
    echo "  Size: \${EXT:-50} extents."
    ;;
  lvextend)
    echo "  Size of logical volume extended to 100 extents (800 MiB)."
    echo "  Logical volume database successfully resized."
    ;;
  lvresize)
    echo "  Logical volume resized successfully."
    ;;
esac
LVCMD
chmod +x /usr/local/bin/$cmd
done

# mkfs variants
for fstype in ext3 ext4 xfs; do
cat > /usr/local/bin/mkfs.$fstype << MKFS
#!/bin/bash
echo "⚡ [mkfs] Creating $fstype filesystem on \$1"
echo "mke2fs 1.46.5 (30-Dec-2021)"
echo "Creating filesystem with 102400 4k blocks and 25688 inodes"
echo "Writing superblocks and filesystem accounting information: done"
MKFS
chmod +x /usr/local/bin/mkfs.$fstype
done

# resize2fs mock
cat > /usr/local/bin/resize2fs << 'R2FS'
#!/bin/bash
echo "⚡ [resize2fs] Resizing filesystem on $1"
echo "resize2fs 1.46.5 (30-Dec-2021)"
echo "The filesystem on $1 is now 102400 (4k) blocks long."
R2FS
chmod +x /usr/local/bin/resize2fs

# dnf mock
cat > /usr/local/bin/dnf << 'DNF'
#!/bin/bash
case "$1" in
  "install")
    shift
    echo "⚡ [dnf] Installing: $@"
    echo "Last metadata expiration check: 0:01:23 ago"
    echo "Dependencies resolved."
    echo "=================================================================================="
    echo " Package            Arch      Version        Repository    Size"
    echo "=================================================================================="
    for pkg in "$@"; do
      [ "$pkg" = "-y" ] && continue
      echo " $pkg              x86_64    latest         AppStream    123 k"
    done
    echo ""
    echo "Transaction Summary"
    echo "=================================================================================="
    echo "Install  $(echo "$@" | wc -w) Package(s)"
    sleep 0.5
    echo ""
    echo "✓ Installed: $@"
    echo "Complete!"
    ;;
  "repolist")
    echo "repo id          repo name"
    echo "AppStream        Red Hat Enterprise Linux 9 - AppStream"
    echo "BaseOS           Red Hat Enterprise Linux 9 - BaseOS"
    ;;
  "update"|"upgrade")
    echo "✓ System is up to date."
    ;;
  *)
    echo "dnf — package manager"
    echo "Usage: dnf install|remove|update|repolist"
    ;;
esac
DNF
chmod +x /usr/local/bin/dnf

# autofs mock
mkdir -p /etc/auto.master.d
touch /etc/auto.master
touch /etc/auto.localhome

echo ""
echo "✅ RHCSA Lab environment ready!"
echo "   Users: harry, natasha, sarah, student, alies"
echo "   Tools: nmcli, hostnamectl, semanage, systemctl, podman, dnf, lvm..."
echo ""
