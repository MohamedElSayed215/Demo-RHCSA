FROM node:20-slim

# Install system packages needed for node-pty and RHCSA tools
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    bash \
    vim \
    nano \
    curl \
    wget \
    sudo \
    cron \
    procps \
    net-tools \
    iproute2 \
    iputils-ping \
    dnsutils \
    lsof \
    htop \
    tree \
    file \
    rsync \
    zip \
    unzip \
    bzip2 \
    xz-utils \
    openssl \
    ca-certificates \
    passwd \
    login \
    adduser \
    && rm -rf /var/lib/apt/lists/*

# Create /sbin/nologin if not present
RUN ln -sf /usr/sbin/nologin /sbin/nologin 2>/dev/null || true

# Set up app directory
WORKDIR /app

# Install Node.js dependencies
COPY package*.json ./
RUN npm install --build-from-source

# Copy application files
COPY . .

# Run the RHCSA environment setup
RUN chmod +x scripts/setup-rhcsa-env.sh && \
    bash scripts/setup-rhcsa-env.sh

# Create a nice .bashrc for root
RUN cat >> /root/.bashrc << 'EOF'

# RHCSA Lab Environment
export PS1='\[\033[1;32m\][root@rhcsa-lab \[\033[1;33m\]\w\[\033[1;32m\]]\[\033[0m\]# '
alias ll='ls -la --color=auto'
alias grep='grep --color=auto'
alias df='df -h'
alias free='free -h'

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║   🖥️  RHCSA Lab Terminal Ready!       ║"
echo "  ║   اكتب 'tasks' لعرض المهام           ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
EOF

# Expose port
EXPOSE 3000

# Start server
CMD ["node", "server.js"]
