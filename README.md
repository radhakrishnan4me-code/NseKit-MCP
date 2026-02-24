# NseKit-MCP — NSE India Real-time & Historical Data Server

**NseKit-MCP** is a high-performance FastMCP (Model Context Protocol) server that exposes **100+ tools** for accessing live and historical data from the **National Stock Exchange of India (NSE)** using the [NseKit](https://github.com/Prasad1612/NseKit) Python library.

Perfect for AI agents (Claude, Grok, GPT, Gemini CLI etc.), trading bots, backtesters, and research platforms.

---

## Features

- **100+ ready-to-use MCP tools** — Live & historical equity, F&O, indices, IPOs, corporate actions
- **HTTP Streamable transport** — Industry-standard MCP transport over HTTP with SSE
- **Bearer token auth** — Secure access via `MCP_BEARER_TOKEN` environment variable
- **n8n compatible** — Connect directly from n8n's MCP Client node
- **Docker ready** — Dockerfile + docker-compose included
- **NSE-safe rate limiting** — Built-in ~3 req/sec throttle
- **Clean JSON output** — Pandas DataFrames → list of dicts

---

## Tool Categories

| Category | Example Tools |
|----------|--------------|
| **Market Status** | `market_live_status`, `market_is_open`, `gift_nifty_live` |
| **Pre-Open** | `preopen_index_summary`, `preopen_data` |
| **Index Live** | `index_live_constituents`, `index_live_data` |
| **Equity Live** | `equity_live_stock_info`, `equity_live_stock_quote`, `equity_52week_high_live` |
| **F&O Live** | `fno_live_option_chain`, `fno_live_futures_data`, `fno_live_change_in_oi` |
| **Historical** | `equity_historical_data`, `fno_historical_data` |
| **EOD Data** | `equity_eod_bhavcopy_delivery`, `fno_eod_bhavcopy` |
| **Corporate Events** | `equity_board_meetings`, `equity_announcements` |
| **IPO** | `ipo_current_list`, `ipo_details` |
| **Charts** | `price_chart_stock`, `price_chart_index`, `fno_intraday_chart` |
| **Regulatory** | `sebi_circulars`, `fii_dii_activity` |
| **Financials** | `quarterly_financial_results` |

All tools return clean JSON arrays.

---

## Quick Start (Docker)

```bash
# 1. Clone the repo
git clone https://github.com/radhakrishnan4me-code/NseKit-MCP.git
cd NseKit-MCP

# 2. Create environment file
cp .env.example .env

# 3. Edit .env — set a strong bearer token
#    Generate one with: openssl rand -hex 32
nano .env

# 4. Build and run
docker compose build
docker compose up -d

# 5. Check logs
docker compose logs -f
# Should see: server listening on 0.0.0.0:8000
```

The server starts on **port 8001** (mapped to container port 8000) with endpoint `/mcp`.

---

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MCP_BEARER_TOKEN` | ✅ | *(empty)* | Bearer token for MCP client authentication |
| `MCP_HOST` | ❌ | `0.0.0.0` | Server bind address |
| `MCP_PORT` | ❌ | `8000` | Server port inside container |

> **Security**: If `MCP_BEARER_TOKEN` is empty, authentication is **disabled** (not recommended for production).

---

## n8n Integration

The MCP server uses **HTTP Streamable** transport with **Bearer authentication**, making it directly compatible with n8n's MCP Client node.

### Setup (Same Docker Network)

If n8n and NseKit-MCP are on the **same Docker network** (e.g., same VPS):

**1. Connect both containers to a shared network:**

```bash
# Create a shared network (if not already)
docker network create mcp-net

# Connect both containers
docker network connect mcp-net nsekit-mcp
docker network connect mcp-net n8n
```

**2. Configure the MCP Client node in n8n:**

| Setting | Value |
|---------|-------|
| **SSE or Streamable HTTP** | `Streamable HTTP` |
| **URL** | `http://nsekit-mcp:8000/mcp` |
| **Authentication** | `Header Auth` |
| **Header Name** | `Authorization` |
| **Header Value** | `Bearer your_token_here` |

> Replace `your_token_here` with the same value you set in `MCP_BEARER_TOKEN` in the `.env` file.

**3. Test the connection** — The MCP Client node should discover all 100+ tools automatically.

### Setup (Different Hosts)

If n8n runs on a different machine:

| Setting | Value |
|---------|-------|
| **SSE or Streamable HTTP** | `Streamable HTTP` |
| **URL** | `http://your-vps-ip:8001/mcp` |
| **Authentication** | `Header Auth` |
| **Header Name** | `Authorization` |
| **Header Value** | `Bearer your_token_here` |

### n8n Workflow Example

1. Add an **AI Agent** node with your preferred LLM (Gemini, OpenAI, etc.)
2. Add an **MCP Client** tool node and configure as above
3. Connect the MCP Client to the AI Agent
4. Ask: *"What is the current market status?"* or *"Show me Nifty 50 option chain for nearest expiry"*

---

## VPS Deployment

```bash
# 1. SSH into your VPS
ssh user@your-vps-ip

# 2. Install Docker (if not installed)
curl -fsSL https://get.docker.com | sh

# 3. Clone the repository
git clone https://github.com/Prasad1612/NseKit-MCP.git /opt/nsekit-mcp
cd /opt/nsekit-mcp

# 4. Configure
cp .env.example .env
# Generate a strong token and edit .env:
echo "MCP_BEARER_TOKEN=$(openssl rand -hex 32)" > .env

# 5. Build and run
docker compose build
docker compose up -d

# 6. Verify
docker compose logs -f
# Should see: server listening on 0.0.0.0:8000

# 7. Test from outside
curl -H "Authorization: Bearer YOUR_TOKEN" http://your-vps-ip:8001/mcp
```

### Nginx Reverse Proxy (Optional — for HTTPS)

If you want SSL/TLS with a domain name:

```nginx
server {
    listen 443 ssl;
    server_name mcp.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/mcp.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mcp.yourdomain.com/privkey.pem;

    location /mcp {
        proxy_pass http://127.0.0.1:8001;
        proxy_buffering off;            # CRITICAL for SSE/streaming
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Connection '';
        chunked_transfer_encoding off;
    }
}
```

> **Important**: You **must** set `proxy_buffering off` for the MCP endpoint, otherwise SSE streaming will break.

Then in n8n, use `https://mcp.yourdomain.com/mcp` as the URL.

---

## Local Development (stdio mode)

For local AI clients (Claude Desktop, Cursor, Cline, Windsurf), you can still use stdio transport.

### Using uvx (recommended)

Add to your MCP client configuration:

```json
{
  "mcpServers": {
    "NseKit-MCP": {
      "command": "uvx",
      "args": ["nsekit-mcp@latest"]
    }
  }
}
```

### Using pip

```bash
pip install uv
pip install nsekit-mcp
nsekit-mcp
```

> **Note**: When running locally via `uvx` or `pip install`, the server uses **stdio** transport by default. The HTTP Streamable transport is activated only when running via Docker/direct Python with the modified `main()`.

---

## Architecture

```
┌─────────────────┐     HTTP Streamable      ┌──────────────────────┐
│   n8n / Claude   │ ═══════════════════════> │   NseKit-MCP Server  │
│   AI Assistant   │    Bearer Auth + SSE     │ (Python, port 8000)  │
└─────────────────┘                           └──────────┬───────────┘
                                                         │ HTTP + Cookies
                                                         │ (rate limited)
                                                         ▼
                                              ┌──────────────────────┐
                                              │      NSE India       │
                                              │   (nseindia.com)     │
                                              └──────────────────────┘
```

- **Transport**: HTTP Streamable (MCP 2025 spec) with SSE for streaming responses
- **Auth**: Bearer token via `Authorization: Bearer <token>` header
- **Rate Limiting**: 0.35s delay between NSE API calls (~3 req/sec)

---

## Maintenance

### Update to latest version

```bash
cd /opt/nsekit-mcp        # or wherever you cloned it
git pull
docker compose build
docker compose up -d
```

### View logs

```bash
docker compose logs -f
```

### Restart

```bash
docker compose restart
```

### Stop

```bash
docker compose down
```

### Change bearer token

```bash
# Edit .env with new token
nano .env

# Restart to apply
docker compose restart
```

> **Remember**: After changing the token, update the n8n MCP Client credential with the new token too.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `401 Unauthorized` on `/mcp` | Check `MCP_BEARER_TOKEN` matches between `.env` and n8n |
| Connection refused on port 8001 | Ensure container is running: `docker compose ps` |
| n8n can't reach MCP server | Both containers must be on the same Docker network |
| NSE data returns empty/errors | VPS must have an **Indian IP** — NSE blocks foreign IPs |
| Build fails on pip install | Ensure `pyproject.toml` and `src/` are present |
| Docker build takes too long | First build downloads dependencies; subsequent builds use cache |
| Rate limit errors from NSE | Built-in 0.35s throttle should handle this; reduce concurrent usage |

---

## NSE IP Restriction

> ⚠️ **Important**: NSE India blocks requests from non-Indian IPs and many data-center IPs. Your VPS **must** have an **Indian IP address**. Standard cloud providers (AWS Mumbai, Azure India, DigitalOcean Bangalore) may or may not work — test before committing to a provider.

---

## Security

⚠️ **Important**: Keep your credentials secure.

- Never commit `.env` to version control
- Use strong, random values for `MCP_BEARER_TOKEN` (`openssl rand -hex 32`)
- Restrict port 8001 access via firewall in production
- Use HTTPS (Nginx + Let's Encrypt) for production deployments
- Consider using Docker secrets for sensitive values

---

## Popular Tools

| Tool | Description |
|------|------------|
| `market_live_status()` | Market open/close, Nifty, Gift Nifty, Mcap |
| `equity_live_stock_info("RELIANCE")` | Live price + 5-level depth + delivery |
| `fno_live_option_chain("NIFTY","27-Jan-2026")` | Nifty/BankNifty option chain data |
| `equity_eod_bhavcopy_delivery("02-12-2025")` | Full day closing + delivery % |
| `fii_dii_activity()` | Latest FII/DII net buying/selling |
| `ipo_current_list()` | All live Mainboard + SME IPOs with subscription |
| `equity_52week_high_live()` | Stocks hitting 52-week high today |
| `price_chart_stock("RELIANCE", "1D")` | Intraday price chart for any stock |
| `quarterly_financial_results("TCS")` | Quarterly financial results |

---

## Safety & Compliance

- Thread-safe rate limiting (0.35s delay between NSE calls)
- Respects NSE's fair usage policy
- For research, personal trading, and AI agent use only

---

## Credits

- Data powered by [NseKit](https://github.com/Prasad1612/NseKit)
- Server powered by [FastMCP](https://github.com/modelcontextprotocol/python-sdk)
- Made with ❤️ for the Indian Quant & Algo community
