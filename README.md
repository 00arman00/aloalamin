# ALO Labs MarketingOS

Enterprise AI Workforce Platform — CRM, Marketing Automation, AI Agents, Video Generation, SMS, VoIP, and more.

## Quick Start

```bash
bun install
cp .env.example .env
# Edit .env with your DATABASE_URL, JWT_SECRET, ADMIN_SEED_PASSWORD
bunx prisma generate
bunx prisma db push
bunx tsx prisma/seed.ts
bun run dev
```

## Production

```bash
bash deploy.sh
```

## Domain: marketing.alolabs.net (103.231.239.79)

## Features (36)
- CRM (Leads, Deals, Contacts, Tickets) with kanban DnD
- AI Agents (23 agents, real LLM calls via z-ai SDK)
- AI Avatar (consistent face + voice for video generation)
- AI Video + Cinematic Video + Video Status
- AI Image + Voice + Grammar Check + Diagram Builder
- AI Memory + Context + Auto-Reply Chatbot
- Text Humanizer
- SMS (send, broadcast, OTP, templates)
- VoIP Click-to-Call
- RSS Feeds + Feed Parser
- Web Scraper (firecrawl pattern)
- Lead Enrichment (open-enrich pattern)
- Market Intelligence Radar
- Competitor + Keyword Tracking
- Workflow Builder + Execute Engine
- CSV Import/Export (RFC-4180 + injection protection)
- Notifications + Bell + Command Palette
- Webhooks (HMAC-SHA256 + SSRF protection)
- Audit Logs + Activity Feed
- Social Media (8 platforms, no WhatsApp)
- SEO Engine
- Campaigns + Content Management
- Analytics
- Team Management
- Settings (Company, API Keys, Webhooks, Sessions, Password)

## Tech Stack
- Next.js 16 (App Router)
- React 19 + TypeScript 5
- Tailwind CSS 4 + shadcn/ui
- Prisma 6 (SQLite dev, MySQL/PostgreSQL prod)
- JWT (jose) + bcryptjs
- z-ai-web-dev-sdk for AI
- 139 API routes, 46 Prisma models, 250 source files
