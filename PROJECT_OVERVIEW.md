# Heroku Agents Buildpack Project

## Overview
This project aims to create a unified buildpack for deploying AI agents on Heroku with native integration of Heroku services. The buildpack will support multiple agent frameworks while providing a seamless developer experience.

## Current Status
We have implemented a basic version of the buildpack with the following features:
- Detection of agent applications via `agent.yaml` or `agent.json` config files
- Support for multiple frameworks:
  - LangChain (implemented)
  - CrewAI (implemented)
- Integration with Heroku Inference API for LLM capabilities
- Automatic resource provisioning for Redis and PostgreSQL (with pgvector)
- Sample agent templates with web search functionality
- Basic MCP server support through FastAPI

## Key Resources

### Heroku Documentation
- [Heroku Inference API (Chat Completions)](https://devcenter.heroku.com/articles/heroku-inference-api-v1-chat-completions)
- [Heroku Inference API (Agents)](https://devcenter.heroku.com/articles/heroku-inference-api-v1-agents-heroku)
- [Heroku Inference Tools](https://devcenter.heroku.com/articles/heroku-inference-tools)
- [Heroku MCP Servers](https://devcenter.heroku.com/articles/heroku-inference-api-v1-mcp-servers)

## Project Decisions

### Primary Approach
- **Single Unified Buildpack**: Create one buildpack that supports multiple agent frameworks
- **Framework Selection**: Allow developers to specify their preferred framework via configuration
- **Resource Provisioning**: Automatically configure Heroku resources (Redis, Postgres, etc.) based on needs

### Supported Frameworks
The buildpack will support the following frameworks, with configuration options for each:
- LangChain (implemented)
- CrewAI (implemented)
- LlamaIndex (planned)
- Pydantic AI (planned)

### Developer Experience
```yaml
# agent.yaml configuration
framework: langchain
agent:
  name: "my-agent"
  description: "Simple LangChain agent"
  model: "gpt-4"

mcp:
  enabled: true
  server_type: "fastmcp"
  
resources:
  memory:
    enabled: true
    type: "redis"
    plan: "mini"
```

## Implementation Status

### Completed
- Basic buildpack structure (detect, compile, release scripts)
- Framework detection and package installation
- Basic resource provisioning logic (Redis, Postgres)
- Sample agent templates for:
  - LangChain: Simple agent with web search capability
  - CrewAI: Multi-agent setup with research and writing specialists
- Heroku Inference API integration

### Key Learnings from Testing
- Heroku Inference add-on provides several environment variables:
  - `INFERENCE_KEY`: API key for authentication
  - `INFERENCE_MODEL_ID`: The provisioned model ID
  - `INFERENCE_URL`: API endpoint URL (e.g., https://us.inference.heroku.com)
- API requirements for follow-up calls:
  - Conversation must start with a user message
  - Tool responses need proper formatting with role=tool
  - First message in any API call must be a user message
- When using LangChain with OpenAI-compatible endpoints:
  - Need to use `openai_api_key` parameter for the key
  - Need to use `openai_api_base` parameter for the base URL
- Available Heroku Inference models include:
  - claude-3-5-haiku
  - claude-3-5-sonnet
  - claude-3-5-sonnet-latest
  - claude-3-7-sonnet
  - claude-3-haiku
  - claude-4-sonnet
  - cohere-embed-multilingual
  - nova-lite
  - nova-pro
  - stable-image-ultra

### Next Steps
- Improve error handling and response validation
- Enhance MCP server support
- Implement agent-to-agent communication
- Add support for LlamaIndex framework
- Add more tool integrations
- Add agent persistence with Redis and PostgreSQL

## Testing Instructions

### Testing the LangChain Agent Template:

1. Clone the repository
2. Copy the template files:
```bash
cp -r templates/langchain/* /path/to/your/app/
```

3. Deploy to Heroku:
```bash
cd /path/to/your/app
heroku create my-langchain-agent
heroku buildpacks:set https://github.com/your-username/heroku-agent-buildpack.git
git push heroku main
```

4. Provision the Heroku Inference add-on and set required environment variables:
```bash
heroku addons:create heroku-inference:claude-3-sonnet
```

5. Test the agent API:
```bash
curl -X POST https://your-app-name.herokuapp.com/agent \
  -H "Content-Type: application/json" \
  -d '{"query": "What is the current weather in San Francisco?", "conversation_id": "test-123"}'
```

### Testing the CrewAI Agent Template:

1. Clone the repository
2. Copy the template files:
```bash
cp -r templates/crewai/* /path/to/your/app/
```

3. Deploy to Heroku:
```bash
cd /path/to/your/app
heroku create my-crewai-agent
heroku buildpacks:set https://github.com/your-username/heroku-agent-buildpack.git
git push heroku main
```

4. Provision the Heroku Inference add-on:
```bash
heroku addons:create heroku-inference:claude-3-sonnet
```

5. Test the crew API:
```bash
curl -X POST https://your-app-name.herokuapp.com/crew \
  -H "Content-Type: application/json" \
  -d '{"query": "Research the impact of AI on healthcare and write a report"}'
```

## Technical Requirements
- Support for various Heroku add-ons (Redis, Postgres, Kafka)
- Integration with Heroku Inference API
- MCP server compatibility
- Tool discovery and registration
- Memory persistence across sessions