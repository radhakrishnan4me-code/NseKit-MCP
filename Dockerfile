FROM python:3.12-slim

WORKDIR /app

# Install dependencies first (better layer caching)
COPY pyproject.toml .
COPY src/ ./src/

RUN pip install --no-cache-dir .

# Default environment
ENV MCP_BEARER_TOKEN=""
ENV MCP_HOST="0.0.0.0"
ENV MCP_PORT="8000"

EXPOSE 8000

ENTRYPOINT ["nsekit-mcp"]
