# Deploying AI Agents with Heroku Agents Buildpack

This guide walks you through deploying AI agents on Heroku using the Heroku Agents Buildpack. We'll create a CrewAI multi-agent application that can research topics and generate reports.

## Introduction

The Heroku Agents Buildpack simplifies the deployment of AI agents powered by LLMs. It detects your preferred agent framework, installs dependencies, and configures necessary resources automatically.

Currently supported frameworks:
- LangChain
- CrewAI

## Prerequisites

Before you begin, ensure you have:

- [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli) installed and authenticated
- [Git](https://git-scm.com/downloads) installed
- Basic Python knowledge
- A Heroku account with billing information

## Step 1: Set Up Your Project

First, clone the example repository:

```bash
git clone https://github.com/example/heroku-agents-buildpack.git
cd heroku-agents-buildpack
```

## Step 2: Choose a Framework Template

For this tutorial, we'll use the CrewAI template to create a multi-agent system:

```bash
cp -r templates/crewai/* ~/my-crew-agent/
cd ~/my-crew-agent
```

## Step 3: Understand the Project Structure

Let's review the key files:

### `agent.yaml`

This configuration file tells the buildpack how to set up your agent:

```yaml
framework: crewai
agent:
  name: "research-crew"
  description: "Research crew using multiple agents"
  model: "claude-3-sonnet"
  
crew:
  process: "sequential"
  verbose: true
  
agents:
  - role: "researcher"
    goal: "Research and gather information"
    tools: ["search"]
  - role: "writer" 
    goal: "Write comprehensive reports"

resources:
  memory:
    enabled: true
    type: "redis"
    plan: "mini"
```

### `app.py`

The main application file that sets up your CrewAI agents:

```python
import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Dict, List, Optional, Any

from crewai import Agent, Task, Crew, Process
from langchain_openai import ChatOpenAI
from langchain.tools import DuckDuckGoSearchRun

app = FastAPI(title="Heroku CrewAI Agent")

class CrewRequest(BaseModel):
    query: str
    inputs: Optional[Dict[str, Any]] = None

class CrewResponse(BaseModel):
    result: str

# Initialize search tool
search_tool = DuckDuckGoSearchRun()

def get_llm():
    """Configure LLM with Heroku Inference API using OpenAI compatibility layer"""
    model_id = os.getenv("INFERENCE_MODEL_ID", "claude-3-sonnet")
    api_key = os.getenv("INFERENCE_KEY")
    base_url = os.getenv("INFERENCE_URL", "https://us.inference.heroku.com")
    
    if not api_key:
        raise ValueError("INFERENCE_KEY environment variable not set")
    
    return ChatOpenAI(
        model_name=model_id,
        openai_api_key=api_key,
        openai_api_base=f"{base_url}/v1",
        temperature=0.7
    )

def create_crew():
    """Create a crew of agents for research and writing tasks."""
    llm = get_llm()
    
    # Research agent
    researcher = Agent(
        role="Research Specialist",
        goal="Find accurate and relevant information",
        backstory="Expert researcher with years of experience",
        verbose=True,
        tools=[search_tool],
        llm=llm
    )
    
    # Writing agent
    writer = Agent(
        role="Content Writer",
        goal="Create comprehensive reports based on research",
        backstory="Skilled writer who excels at synthesizing information",
        verbose=True,
        llm=llm
    )
    
    return Crew(
        agents=[researcher, writer],
        process=Process.sequential,
        verbose=True,
    )

@app.post("/crew")
async def run_crew(request: CrewRequest):
    """Process a request using a CrewAI crew."""
    try:
        # Initialize crew
        crew = create_crew()
        
        # Prepare inputs
        inputs = request.inputs or {}
        inputs["query"] = request.query
        
        # Create research task
        research_task = Task(
            description=f"Research the topic: {request.query}",
            expected_output="Detailed research findings with facts and references",
            agent=crew.agents[0],
        )
        
        # Create writing task
        writing_task = Task(
            description="Create a comprehensive report based on research findings",
            expected_output="Well-structured report with insights and conclusions",
            agent=crew.agents[1],
            context=[research_task]
        )
        
        # Set tasks and execute
        crew.tasks = [research_task, writing_task]
        result = crew.kickoff(inputs=inputs)
        
        return CrewResponse(result=result)
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
```

### `requirements.txt`

Dependencies for your project:

```
fastapi>=0.95.1
uvicorn>=0.22.0
crewai>=0.28.8
langchain>=0.1.0
langchain-openai>=0.0.2
openai>=0.28.1
langchain-community>=0.0.20
duckduckgo-search>=3.8.3
python-dotenv>=1.0.0
pydantic>=2.4.0
```

### `Procfile`

Tells Heroku how to run your application:

```
web: python -m uvicorn app:app --host 0.0.0.0 --port $PORT
```

## Step 4: Initialize Git Repository

```bash
git init
git add .
git commit -m "Initial commit"
```

## Step 5: Create Heroku App and Set Buildpack

```bash
heroku create my-research-crew
heroku buildpacks:set https://github.com/example/heroku-agents-buildpack.git
```

## Step 6: Add Heroku Inference Add-on

```bash
heroku addons:create heroku-inference:claude-3-sonnet
```

This add-on provides your application with:
- `INFERENCE_KEY` - API key for authentication
- `INFERENCE_URL` - API endpoint URL
- `INFERENCE_MODEL_ID` - The provisioned model name

## Step 7: Deploy to Heroku

```bash
git push heroku main
```

During deployment, the buildpack will:
1. Detect your agent framework (CrewAI)
2. Install required dependencies
3. Provision Redis for memory (as specified in agent.yaml)
4. Configure the application with Heroku Inference

## Step 8: Test Your Agent

Once deployed, you can test your multi-agent crew:

```bash
curl -X POST https://my-research-crew.herokuapp.com/crew \
  -H "Content-Type: application/json" \
  -d '{"query": "Explain the impact of AI on healthcare"}'
```

The response will contain a comprehensive report created by your agent crew, with research findings and a structured analysis:

```json
{
  "result": "# AI Impact on Healthcare: Research Report\n\n## Executive Summary\nArtificial intelligence is transforming healthcare through improved diagnostics, personalized treatment recommendations, and operational efficiency. This report analyzes key developments and future implications.\n\n## Research Findings\n\n### Current Applications\n- AI diagnostic systems show 95% accuracy in medical imaging analysis\n- Virtual health assistants handle 35% of routine patient inquiries\n- Predictive analytics reduce hospital readmissions by 18%\n\n### Major Developments\n- FDA has approved 29 AI-based medical algorithms since 2021\n- Investment in healthcare AI reached $6.6 billion in 2023\n- 83% of healthcare executives report active AI implementation strategies\n\n## Impact Analysis\n\n### Benefits\n- Earlier disease detection through advanced pattern recognition\n- Reduced healthcare costs through automation and efficiency\n- Improved access to care in underserved regions\n\n### Challenges\n- Data privacy and security concerns\n- Regulatory framework still developing\n- Need for healthcare professional training\n\n## Future Outlook\nAI will continue reshaping healthcare delivery models, with particular growth in personalized medicine, drug discovery, and preventative care. Integration challenges remain, but the trajectory indicates transformative potential for patient outcomes and healthcare economics.\n\n## References\n[List of key sources and research papers]"
}
```

## How It Works

1. **Framework Detection**: The buildpack identifies CrewAI as your framework from agent.yaml
2. **Dependency Installation**: Core CrewAI libraries are installed automatically
3. **Resource Provisioning**: Redis is set up for memory management
4. **Heroku Inference Integration**: The API key and endpoint are configured via OpenAI compatibility layer
5. **Agent Execution**: When API requests come in:
   - The researcher agent uses search tools to gather information
   - The writer agent processes the research and creates a report
   - Results are returned to the user

> **Important Note**: The Heroku Inference API provides an OpenAI-compatible interface. Although it serves Claude models, we connect using the OpenAI client library rather than the Anthropic client.

## Advanced Configuration

### Modifying Agent Behavior

You can customize agent roles, goals, and tools by modifying `app.py`:

```python
# Example: Adding a data analysis agent
analyst = Agent(
    role="Data Analyst",
    goal="Analyze data and extract insights",
    backstory="Expert in data science and statistics",
    verbose=True,
    tools=[pandas_tool, visualization_tool],  # Custom tools
    llm=llm
)

# Update crew with new agent
crew = Crew(
    agents=[researcher, analyst, writer],
    process=Process.sequential,
    verbose=True,
)
```

### Adding Custom Tools

Create custom tools for your agents:

```python
from langchain.tools import BaseTool

class CustomDatabaseTool(BaseTool):
    name = "database_search"
    description = "Search a specific database for information"
    
    def _run(self, query: str) -> str:
        # Implementation to search your database
        return "Database search results for: " + query
        
# Add to your researcher agent
researcher = Agent(
    # ... other parameters ...
    tools=[search_tool, CustomDatabaseTool()],
    llm=llm
)
```

### Scaling Resources

For production workloads, increase your dyno size:

```bash
heroku ps:scale web=standard-2x
```

## Best Practices

1. **Handle Timeouts**: CrewAI operations can take time. Configure timeout settings for complex tasks.

2. **Monitor Costs**: LLM API calls can add up. Implement usage tracking and limits.

3. **Test Locally**: Before deploying, test with local LLM options or mocked responses.

4. **Implement Caching**: Reduce duplicate LLM calls by caching common responses.

5. **Add Error Handling**: Robust error handling improves reliability:

```python
try:
    result = crew.kickoff(inputs=inputs)
    return CrewResponse(result=result)
except Exception as e:
    logger.error(f"Crew execution error: {str(e)}", exc_info=True)
    # Fall back to a simpler response method
    return CrewResponse(result="Unable to complete the full analysis. Here's what we found: [partial results]")
```

## Conclusion

You've successfully deployed a CrewAI multi-agent system on Heroku using the Agents Buildpack. This system demonstrates how multiple AI agents can collaborate to perform complex tasks like research and report generation.

The buildpack handles the infrastructure setup, allowing you to focus on designing effective agent behaviors and interactions. As you expand your application, you can add more specialized agents, custom tools, and complex workflows to tackle increasingly sophisticated use cases.

## Additional Resources

- [CrewAI Documentation](https://docs.crewai.com/)
- [Heroku Inference API Documentation](https://devcenter.heroku.com/articles/heroku-inference-api)
- [Agents Buildpack Repository](https://github.com/example/heroku-agents-buildpack)