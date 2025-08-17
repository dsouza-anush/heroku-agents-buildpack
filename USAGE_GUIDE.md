# Heroku Agents Buildpack Usage Guide

This guide explains how to use the Heroku Agents Buildpack to deploy AI agents on the Heroku platform using different agent frameworks.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Framework Options](#framework-options)
  - [LangChain](#langchain)
  - [CrewAI](#crewai)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [Important Notes](#important-notes)

## Overview

The Heroku Agents Buildpack streamlines the deployment of AI agents on Heroku by automatically:

1. Detecting your preferred agent framework (LangChain, CrewAI, etc.)
2. Installing appropriate dependencies
3. Setting up necessary Heroku resources (Redis, PostgreSQL, etc.)
4. Configuring integration with Heroku Inference API for LLM capabilities
5. Provisioning resources based on your agent configuration

## Prerequisites

- Heroku account with billing information
- Git installed on your local machine
- Heroku CLI installed and authenticated
- Basic knowledge of the agent framework you want to use

## Getting Started

Follow these steps to get started with the Heroku Agents Buildpack:

1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/heroku-agent-buildpack.git
   ```

2. Choose a template based on your preferred framework:
   ```bash
   cp -r templates/langchain/* /path/to/your/app/
   # OR
   cp -r templates/crewai/* /path/to/your/app/
   ```

3. Customize the agent implementation in `app.py` to fit your use case

4. Deploy to Heroku (see [Deployment](#deployment) section below)

## Framework Options

### LangChain

The LangChain template provides a simple agent with web search capabilities using the Heroku Inference API.

**Key features:**
- FastAPI server with agent endpoint
- Tool execution flow with web search
- Conversation history tracking
- Integration with Heroku Inference API via OpenAI compatibility layer

**Sample API call:**
```bash
curl -X POST https://your-app-name.herokuapp.com/agent \
  -H "Content-Type: application/json" \
  -d '{"query": "What is the current weather in San Francisco?", "conversation_id": "test-123"}'
```

### CrewAI

The CrewAI template implements a multi-agent system with specialized roles for research and content creation.

**Key features:**
- Multiple agents with different capabilities
- Sequential task execution
- Researcher and writer agent collaboration
- Document generation from research findings
- Integration with Heroku Inference API via OpenAI compatibility layer

**Sample API call:**
```bash
curl -X POST https://your-app-name.herokuapp.com/crew \
  -H "Content-Type: application/json" \
  -d '{"query": "Research the impact of AI on healthcare and write a report"}'
```

## Configuration

Configuration is done via an `agent.yaml` or `agent.json` file in the root of your project:

```yaml
framework: langchain  # or crewai
agent:
  name: "my-agent"
  description: "Simple agent with search capabilities"
  model: "claude-3-sonnet"

mcp:
  enabled: true
  server_type: "fastmcp"
  
resources:
  memory:
    enabled: true
    type: "redis"
    plan: "mini"
  vector:
    enabled: false  # Set to true if you need vector storage
    type: "postgres"
    plan: "mini"
```

## Deployment

To deploy your agent to Heroku:

1. Create a new Heroku app:
   ```bash
   cd /path/to/your/app
   heroku create my-agent-app
   ```

2. Set the Heroku Agents Buildpack:
   ```bash
   heroku buildpacks:set https://github.com/your-username/heroku-agent-buildpack.git
   ```

3. Provision the Heroku Inference add-on:
   ```bash
   heroku addons:create heroku-inference:claude-3-sonnet
   ```

4. Deploy your app:
   ```bash
   git push heroku main
   ```

5. Open your app:
   ```bash
   heroku open
   ```

## API Reference

### LangChain Agent API

**Endpoint:** `/agent`

**Method:** POST

**Request:**
```json
{
  "query": "Your query here",
  "conversation_id": "optional-conversation-id"
}
```

**Response:**
```json
{
  "response": "Agent's response to the query",
  "conversation_id": "conversation-id"
}
```

### CrewAI Agent API

**Endpoint:** `/crew`

**Method:** POST

**Request:**
```json
{
  "query": "Your query here",
  "inputs": {
    "optional_parameter1": "value1",
    "optional_parameter2": "value2"
  }
}
```

**Response:**
```json
{
  "result": "Result from the crew execution"
}
```

## Examples

### Simple Question-Answering with LangChain

```bash
curl -X POST https://your-app-name.herokuapp.com/agent \
  -H "Content-Type: application/json" \
  -d '{"query": "What is quantum computing?"}'
```

### Research Report with CrewAI

```bash
curl -X POST https://your-app-name.herokuapp.com/crew \
  -H "Content-Type: application/json" \
  -d '{"query": "Analyze the trends in renewable energy adoption over the last decade"}'
```

## Troubleshooting

Common issues and solutions:

1. **Missing INFERENCE_KEY error:**
   - Ensure you've provisioned the Heroku Inference add-on
   - Check your Heroku environment variables with `heroku config`

2. **Dependencies not installing:**
   - Verify your requirements.txt file
   - Check your framework specification in agent.yaml/agent.json

3. **API timeout:**
   - Complex agent tasks might require increasing your dyno's timeout setting
   - Consider breaking complex tasks into smaller subtasks

4. **Memory issues:**
   - Upgrade to a larger dyno size if you're running into memory limitations
   - Enable Redis for efficient memory management

5. **Tool execution failures:**
   - Check the tool implementation and required credentials
   - Verify network connectivity to external services

For more detailed help, check the logs:
```bash
heroku logs --tail
```

## Important Notes

### Heroku Inference API OpenAI Compatibility

The Heroku Inference API provides OpenAI-compatible endpoints for accessing Claude models. Despite using Claude models, you need to use the OpenAI client libraries (not Anthropic libraries) to interface with this API. The buildpack handles this by:

1. Installing the necessary OpenAI dependencies
2. Configuring the API base URL to point to the Heroku Inference endpoint
3. Using the INFERENCE_KEY as the OpenAI API key

When developing your own agents, always use the OpenAI client patterns:  

```python
# For direct API calls
from openai import OpenAI

client = OpenAI(
    api_key=os.getenv("INFERENCE_KEY"),
    base_url=f"{os.getenv('INFERENCE_URL', 'https://us.inference.heroku.com')}/v1"
)

# For LangChain integration
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model_name=os.getenv("INFERENCE_MODEL_ID", "claude-3-sonnet"),
    openai_api_key=os.getenv("INFERENCE_KEY"),
    openai_api_base=f"{os.getenv('INFERENCE_URL', 'https://us.inference.heroku.com')}/v1"
)

# For CrewAI integration
from crewai import Agent
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model_name=os.getenv("INFERENCE_MODEL_ID", "claude-3-sonnet"),
    openai_api_key=os.getenv("INFERENCE_KEY"),
    openai_api_base=f"{os.getenv('INFERENCE_URL', 'https://us.inference.heroku.com')}/v1"
)

agent = Agent(
    role="Researcher",
    goal="Find accurate information",
    backstory="Expert researcher",
    llm=llm
)
```