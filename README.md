# Heroku Agents Buildpack

A buildpack to easily deploy AI agents on Heroku using multiple agent frameworks.

## Features

- Support for multiple agent frameworks:
  - LangChain
  - CrewAI
- Automatic integration with Heroku Inference API
- Resource provisioning for Redis and PostgreSQL
- Simple configuration via YAML or JSON

## Requirements

- Heroku account with billing information
- Git
- Heroku CLI

## Quick Start

1. Create a new directory for your agent:

```bash
mkdir my-agent
cd my-agent
```

2. Choose a template based on your preferred framework:

**For LangChain:**
```bash
git clone https://github.com/dsouza-anush/heroku-agents-buildpack.git
cp -r heroku-agents-buildpack/templates/langchain/* .
```

**For CrewAI:**
```bash
git clone https://github.com/dsouza-anush/heroku-agents-buildpack.git
cp -r heroku-agents-buildpack/templates/crewai/* .
```

3. Initialize git and create a Heroku app:

```bash
git init
git add .
git commit -m "Initial commit"
heroku create my-agent-name
```

4. Set the buildpack:

```bash
heroku buildpacks:set https://github.com/dsouza-anush/heroku-agents-buildpack.git
```

5. Provision the Heroku Inference add-on:

```bash
heroku addons:create heroku-inference:claude-3-sonnet
```

6. Deploy your app:

```bash
git push heroku main
```

## Configuration

Create an `agent.yaml` file in your project root:

```yaml
framework: langchain  # or crewai
agent:
  name: "my-agent"
  description: "Simple agent with search capabilities"
  model: "claude-3-sonnet"

resources:
  memory:
    enabled: true
    type: "redis"
    plan: "mini"
  vector:
    enabled: false
    type: "postgres"
    plan: "mini"
```

## Templates

### LangChain Template

A simple agent with web search capabilities:
- FastAPI server with `/agent` endpoint
- Tool execution with DuckDuckGo search
- Conversation history tracking

### CrewAI Template

A multi-agent system with specialized roles:
- Research specialist agent that gathers information
- Content writer agent that creates reports
- Sequential task execution
- Document generation from research

## OpenAI Compatibility Layer

The buildpack configures your agent to use the Heroku Inference API through the OpenAI compatibility layer:

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model_name=os.getenv("INFERENCE_MODEL_ID", "claude-3-sonnet"),
    openai_api_key=os.getenv("INFERENCE_KEY"),
    openai_api_base=f"{os.getenv('INFERENCE_URL', 'https://us.inference.heroku.com')}/v1"
)
```

## Documentation

For detailed information, see:

- [Usage Guide](USAGE_GUIDE.md) - Complete guide for using the buildpack
- [DevCenter Style Guide](DEVCENTER.md) - Detailed tutorial with examples
- [Project Overview](PROJECT_OVERVIEW.md) - Technical details and implementation status

## Environment Variables

- `AGENT_FRAMEWORK`: Override the framework specified in agent.yaml
- `AGENT_MODEL`: Override the model specified in agent.yaml
- `INFERENCE_KEY`: API key for Heroku Inference (set automatically by the add-on)
- `INFERENCE_URL`: API endpoint URL (set automatically by the add-on)
- `INFERENCE_MODEL_ID`: The provisioned model name (set automatically by the add-on)

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request