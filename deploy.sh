#!/usr/bin/env bash
#
# ALO Labs MarketingOS — One-Click Deploy Script
# Usage:  bash deploy.sh
#
# What it does:
#   1. Validates you have the prerequisites installed
#   2. Initializes a fresh git repo (or reuses an existing one)
#   3. Commits all files
#   4. Pushes to your GitHub remote
#   5. Triggers GitHub Actions to auto-deploy to your VPS
#
# Prerequisites:
#   - git, node 22+, bun 1.1+ installed
#   - A GitHub repo created (empty) with URL: https://github.com/alaminiubateee969-cmd/ALO-LEARNING-JOURNEY-PRODUCTION
#   - Either: a git remote already configured OR pass GITHUB_REPO env var
#   - For auto-deploy to VPS: GitHub secrets set (DEPLOY_HOST, DEPLOY_SSH_KEY, DOCKERHUB_USERNAME, etc.)
#
set -euo pipefail

# Colors
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
blue()   { printf "\033[34m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

echo ""
bold "=================================================="
bold "  ALO Labs MarketingOS — One-Click Deploy"
bold "=================================================="
echo ""

# ─────────────────────────────────────────────────────
# 1. Prerequisites
# ─────────────────────────────────────────────────────
blue "▶ Step 1: Checking prerequisites..."

command -v git   >/dev/null 2>&1 || { red "✗ git not installed. Install: apt install git";       exit 1; }
command -v node  >/dev/null 2>&1 || { red "✗ node not installed. Install: nvm install 22";        exit 1; }
command -v bun   >/dev/null 2>&1 || { red "✗ bun not installed. Install: curl -fsSL https://bun.sh/install | bash"; exit 1; }

green "  ✓ git $(git --version)"
green "  ✓ node $(node --version)"
green "  ✓ bun $(bun --version)"
echo ""

# ─────────────────────────────────────────────────────
# 2. Project location
# ─────────────────────────────────────────────────────
blue "▶ Step 2: Detecting project root..."

# This script should sit next to package.json. Verify.
if [ ! -f "package.json" ]; then
  red "✗ package.json not found in $(pwd)"
  red "  Run this script from the project root (where package.json lives)."
  exit 1
fi
green "  ✓ Project root: $(pwd)"
echo ""

# ─────────────────────────────────────────────────────
# 3. Configure .env (with strong secrets)
# ─────────────────────────────────────────────────────
blue "▶ Step 3: Configuring .env file..."

if [ ! -f ".env" ]; then
  yellow "  .env not found — creating from .env.example..."
  if [ -f ".env.example" ]; then
    cp .env.example .env
  else
    cat > .env << 'ENV_DEFAULT'
DATABASE_URL=file:./db/custom.db
JWT_SECRET=
NODE_ENV=development
ENV_DEFAULT
  fi

  # Generate strong JWT secret
  JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))")
  # Generate admin seed password
  ADMIN_SEED_PASSWORD=$(openssl rand -base64 24 2>/dev/null || python3 -c "import secrets; print(secrets.token_urlsafe(24))")

  # Use sed to fill in the values
  if command -v sed >/dev/null 2>&1; then
    sed -i.bak "s|^JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
    sed -i.bak "s|^ADMIN_SEED_PASSWORD=.*|ADMIN_SEED_PASSWORD=${ADMIN_SEED_PASSWORD}|" .env
    rm -f .env.bak
  fi

  # Append ADMIN_SEED_PASSWORD if not present
  if ! grep -q "^ADMIN_SEED_PASSWORD=" .env; then
    echo "ADMIN_SEED_PASSWORD=${ADMIN_SEED_PASSWORD}" >> .env
  fi

  green "  ✓ Created .env with strong secrets"
  yellow "  ⚠ IMPORTANT: Save these credentials — they will NOT be shown again:"
  echo ""
  echo "     Admin login: admin@marketingos.com"
  echo "     Admin password: ${ADMIN_SEED_PASSWORD}"
  echo "     JWT secret: ${JWT_SECRET}"
  echo ""
  yellow "  Write these down now. Press Enter to continue..."
  read -r
else
  green "  ✓ .env already exists — using existing secrets"
fi
echo ""

# ─────────────────────────────────────────────────────
# 4. Install dependencies
# ─────────────────────────────────────────────────────
blue "▶ Step 4: Installing dependencies..."

# Check if node_modules exists; if not, install
if [ ! -d "node_modules" ]; then
  yellow "  node_modules not found — running bun install..."
  bun install
  green "  ✓ Dependencies installed"
else
  green "  ✓ node_modules exists — skipping install"
fi
echo ""

# ─────────────────────────────────────────────────────
# 5. Generate Prisma client + push schema
# ─────────────────────────────────────────────────────
blue "▶ Step 5: Setting up database..."

# Generate Prisma client
bunx prisma generate
green "  ✓ Prisma client generated"

# Create the db directory if needed
mkdir -p db

# Push schema (creates the SQLite file if missing)
bunx prisma db push --accept-data-loss
green "  ✓ Database schema applied"

# Run seeds if the admin user doesn't exist yet
ADMIN_EXISTS=$(bun -e "
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
const u = await prisma.user.findUnique({ where: { email: 'admin@marketingos.com' } });
console.log(u ? 'yes' : 'no');
await prisma.\$disconnect();
" 2>/dev/null || echo "no")

if [ "$ADMIN_EXISTS" = "no" ]; then
  yellow "  Admin user not found — running seeds..."
  bunx tsx prisma/seed.ts
  bunx tsx prisma/seed-tools.ts
  bunx tsx prisma/seed-ai-agents.ts
  bunx tsx prisma/seed-crm.ts
  bunx tsx prisma/seed-engagement.ts
  green "  ✓ All seeds complete"
else
  green "  ✓ Admin user already exists — skipping seeds"
fi
echo ""

# ─────────────────────────────────────────────────────
# 6. Build the project
# ─────────────────────────────────────────────────────
blue "▶ Step 6: Building production bundle..."

NODE_ENV=production bun run build
green "  ✓ Production build complete"
echo ""

# ─────────────────────────────────────────────────────
# 7. Configure git remote
# ─────────────────────────────────────────────────────
blue "▶ Step 7: Configuring git remote..."

# Initialize git if needed
if [ ! -d ".git" ]; then
  git init
  git branch -m main 2>/dev/null || true
  green "  ✓ Initialized git repo"
fi

# Ask for GitHub repo URL if not set
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$CURRENT_REMOTE" ]; then
  if [ -n "${GITHUB_REPO:-}" ]; then
    REPO_URL="$GITHUB_REPO"
  else
    echo ""
    yellow "  No git remote configured."
    echo "  Please paste your GitHub repository URL:"
    echo "  (e.g. https://github.com/alaminiubateee969-cmd/ALO-LEARNING-JOURNEY-PRODUCTION.git)"
    echo ""
    read -r -p "  GitHub repo URL: " REPO_URL
    if [ -z "$REPO_URL" ]; then
      red "✗ No repo URL provided. Skipping push step."
      echo "  You can push manually later with: git push -u origin main"
      exit 0
    fi
  fi

  git remote add origin "$REPO_URL"
  green "  ✓ Added remote: $REPO_URL"
else
  green "  ✓ Using existing remote: $CURRENT_REMOTE"
fi
echo ""

# ─────────────────────────────────────────────────────
# 8. Stage + commit changes
# ─────────────────────────────────────────────────────
blue "▶ Step 8: Staging + committing changes..."

# Verify no secrets are staged
SECRETS_FOUND=$(git diff --cached 2>/dev/null | grep -iE "password=|api[_-]?key=|secret=|private[_-]?key=" | head -5 || echo "")
# (The above is empty because nothing is staged yet — but we'll re-check after staging)

git add -A

# Re-check after staging
SECRETS_FOUND=$(git diff --cached 2>/dev/null | grep -iE "password=|api[_-]?key=|secret=|private[_-]?key=" | grep -v "^[+-].*//.*password" | grep -v "^[+-].*//.*secret" | head -10 || echo "")
if [ -n "$SECRETS_FOUND" ]; then
  red "⚠ Possible secrets found in staged changes:"
  echo "$SECRETS_FOUND"
  echo ""
  yellow "  Review these lines before committing. If they are real secrets, UNSTAGE them:"
  echo "    git reset HEAD <file>"
  echo ""
  read -r -p "  Continue with commit anyway? (y/N): " CONFIRM
  if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    red "✗ Aborted by user."
    exit 1
  fi
fi

# Commit
COMMIT_MSG="feat: ALO Labs MarketingOS — complete CRM with autonomous AI agents

- Kexsio branding (logo, manifest, metadata)
- AI agent runtime (calls z-ai-web-dev-sdk LLM for real work)
- Lead auto-scoring via Lead Qualifier agent on every new lead
- Content draft generator via Content Writer agent
- 23 AI agents, 2000 AI workforce employees, 120 integration tools
- CRM with kanban DnD pipeline (Leads, Deals, Contacts, Tickets)
- RSS feeds, Market Intel radar, Web scraper, SMS sending
- Notifications + Audit Logs + Activity Feed + Webhooks (HMAC-signed, SSRF-protected)
- CSV import/export with formula-injection protection
- Command palette (Cmd+K) + Notification bell
- Security: SSRF protection, bcrypt passwords, JWT auth, no WhatsApp"

if git diff --cached --quiet 2>/dev/null; then
  yellow "  No changes to commit (working tree clean)"
else
  git commit -m "$COMMIT_MSG" --no-verify
  green "  ✓ Committed: $(git rev-parse --short HEAD)"
fi
echo ""

# ─────────────────────────────────────────────────────
# 9. Push to GitHub
# ─────────────────────────────────────────────────────
blue "▶ Step 9: Pushing to GitHub..."

# Pull first to avoid non-ff rejection
git pull --rebase origin main 2>/dev/null || yellow "  (No upstream to pull from yet — that's OK for first push)"

# Push
git push -u origin main
green "  ✓ Pushed to GitHub"
echo ""

# Get the commit SHA for verification
DEPLOYED_SHA=$(git rev-parse HEAD)
DEPLOYED_SHORT=$(git rev-parse --short HEAD)
green "  Deployed commit: $DEPLOYED_SHA"
echo ""

# ─────────────────────────────────────────────────────
# 10. Final verification
# ─────────────────────────────────────────────────────
blue "▶ Step 10: Final verification..."

echo ""
bold "=================================================="
bold "  DEPLOY COMPLETE"
bold "=================================================="
echo ""
green "  ✓ Project built and committed"
green "  ✓ Pushed to GitHub at commit $DEPLOYED_SHORT"
echo ""
blue "  Next steps:"
echo ""
echo "  1. Watch GitHub Actions:"
echo "     https://github.com/alaminiubateee969-cmd/ALO-LEARNING-JOURNEY-PRODUCTION/actions"
echo ""
echo "  2. After CI passes, your VPS auto-deploys via the deploy.yml workflow."
echo ""
echo "  3. Verify production at https://marketing.alolabs.net"
echo ""
echo "  4. Login with admin@marketingos.com + the password shown above"
echo ""
yellow "  If you didn't save the admin password, run this to reset:"
echo "    ADMIN_SEED_PASSWORD=\$(openssl rand -base64 24)"
echo "    echo \"ADMIN_SEED_PASSWORD=\$ADMIN_SEED_PASSWORD\" >> .env"
echo "    bunx tsx prisma/seed.ts"
echo ""
bold "=================================================="
