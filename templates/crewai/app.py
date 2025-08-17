"""
CrewAI agent using Heroku Inference API with OpenAI-compatible interface.
"""
import os
import json
from typing import Dict, List, Optional, Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from crewai import Agent, Task, Crew, Process
from langchain_openai import ChatOpenAI
from langchain.tools import DuckDuckGoSearchRun

# Create FastAPI app
app = FastAPI(title="Heroku CrewAI Agent", description="A multi-agent crew using CrewAI and Heroku Inference API")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Define request models
class CrewRequest(BaseModel):
    query: str
    inputs: Optional[Dict[str, Any]] = None

class CrewResponse(BaseModel):
    result: str

# Initialize tools
search_tool = DuckDuckGoSearchRun()

def get_llm():
    """Get LLM configured for Heroku Inference API using OpenAI compatibility layer."""
    model_id = os.getenv("INFERENCE_MODEL_ID", "claude-3-sonnet")
    api_key = os.getenv("INFERENCE_KEY")
    base_url = os.getenv("INFERENCE_URL", "https://us.inference.heroku.com")
    
    if not api_key:
        raise ValueError("INFERENCE_KEY environment variable not set")
    
    # Configure OpenAI-compatible client with Heroku Inference API
    return ChatOpenAI(
        model_name=model_id,
        openai_api_key=api_key,
        openai_api_base=f"{base_url}/v1",
        temperature=0.7
    )

def create_crew():
    """Create a crew of agents for research and writing tasks."""
    llm = get_llm()
    
    # Define agents
    researcher = Agent(
        role="Research Specialist",
        goal="Find accurate and relevant information on any topic",
        backstory="You are an expert researcher with years of experience finding information. You have a talent for locating the most relevant details quickly and efficiently.",
        verbose=True,
        allow_delegation=True,
        tools=[search_tool],
        llm=llm
    )
    
    writer = Agent(
        role="Content Writer",
        goal="Create comprehensive and engaging reports based on research",
        backstory="You are a skilled writer who excels at synthesizing information into clear, well-organized content. You have a talent for explaining complex topics in an accessible way.",
        verbose=True,
        allow_delegation=False,
        llm=llm
    )
    
    # Create the crew
    crew = Crew(
        agents=[researcher, writer],
        process=Process.sequential,
        verbose=True,
    )
    
    return crew

@app.get("/")
async def root():
    return {"status": "ok", "message": "Heroku CrewAI Agent is running"}

@app.post("/crew")
async def run_crew(request: CrewRequest):
    """Process a request using a CrewAI crew."""
    try:
        # Initialize the crew
        crew = create_crew()
        
        # Prepare inputs
        inputs = request.inputs or {}
        inputs["query"] = request.query
        
        # Create dynamic tasks based on the query
        research_task = Task(
            description=f"Research the following topic thoroughly: {request.query}",
            expected_output="Detailed research findings with facts, figures, and references",
            agent=crew.agents[0],  # researcher
        )
        
        writing_task = Task(
            description="Create a comprehensive report based on the research findings",
            expected_output="Well-structured report with clear sections, insights, and conclusions",
            agent=crew.agents[1],  # writer
            context=[research_task]
        )
        
        # Add tasks to crew
        crew.tasks = [research_task, writing_task]
        
        # Execute the crew
        result = crew.kickoff(inputs=inputs)
        
        return CrewResponse(result=result)
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)