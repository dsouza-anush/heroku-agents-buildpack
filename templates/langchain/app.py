"""
LangChain agent template for Heroku Agents buildpack.
"""
import os
from typing import Dict, List, Optional

from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from langchain.agents import initialize_agent, AgentType
from langchain.memory import ConversationBufferMemory
from langchain_community.llms.openai import OpenAI  # Using OpenAI interface for compatibility
from langchain.tools import Tool, DuckDuckGoSearchRun, WikipediaQueryRun
from langchain.callbacks.manager import CallbackManager
from langchain.callbacks.streaming_stdout import StreamingStdOutCallbackHandler
from langchain_experimental.tools import PythonAstREPLTool
import os

# Create FastAPI app
app = FastAPI(title="LangChain Agent", description="A simple LangChain agent with web search capabilities")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Define request models
class AgentRequest(BaseModel):
    query: str
    conversation_id: Optional[str] = None
    streaming: bool = False

class AgentResponse(BaseModel):
    response: str
    conversation_id: str

# Initialize tools
search_tool = DuckDuckGoSearchRun()
calculator = PythonAstREPLTool()

tools = [
    Tool(
        name="Search",
        func=search_tool.run,
        description="Useful for searching the internet for current information"
    ),
    Tool(
        name="Calculator",
        func=calculator.run,
        description="Useful for performing calculations"
    )
]

# Memory store
memories: Dict[str, ConversationBufferMemory] = {}

def get_memory(conversation_id: str) -> ConversationBufferMemory:
    """Get or create a memory instance for a conversation."""
    if conversation_id not in memories:
        memories[conversation_id] = ConversationBufferMemory(memory_key="chat_history", return_messages=True)
    return memories[conversation_id]

# Define agent routes
@app.get("/")
async def root():
    return {"status": "ok", "message": "LangChain Agent is running"}

@app.post("/agent")
async def run_agent(request: AgentRequest) -> AgentResponse:
    """Run the agent with the provided query."""
    # Set up memory
    conversation_id = request.conversation_id or os.urandom(16).hex()
    memory = get_memory(conversation_id)
    
    # Set up LLM using Heroku Inference API (OpenAI compatible)
    model_name = os.getenv("AGENT_MODEL", "claude-3-sonnet")
    api_key = os.getenv("HEROKU_API_KEY")
    base_url = os.getenv("HEROKU_INFERENCE_URL", "https://inference.heroku.com/v1")
    
    # Set up callbacks
    callbacks = []
    if request.streaming:
        callbacks.append(StreamingStdOutCallbackHandler())
    
    # Initialize LLM
    llm = OpenAI(
        temperature=0,
        model_name=model_name,
        openai_api_key=api_key,
        openai_api_base=base_url,
        callback_manager=CallbackManager(callbacks) if callbacks else None
    )
    
    # Initialize agent
    agent = initialize_agent(
        tools=tools,
        llm=llm,
        agent=AgentType.CHAT_CONVERSATIONAL_REACT_DESCRIPTION,
        memory=memory,
        verbose=True
    )
    
    # Run agent
    try:
        response = agent.run(request.query)
        return AgentResponse(response=response, conversation_id=conversation_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/conversations/{conversation_id}")
async def delete_conversation(conversation_id: str):
    """Delete a conversation from memory."""
    if conversation_id in memories:
        del memories[conversation_id]
        return {"status": "ok", "message": f"Conversation {conversation_id} deleted"}
    raise HTTPException(status_code=404, detail=f"Conversation {conversation_id} not found")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)