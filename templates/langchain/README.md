# LangChain Agent Template

This is a template for creating a LangChain-based agent using the Heroku Agents buildpack.

## Setup

1. Make sure you have the following environment variables set:
   - `HEROKU_API_KEY` - Your Heroku API key
   - `AGENT_MODEL` (optional) - The model to use, defaults to claude-3-sonnet
   - `HEROKU_INFERENCE_URL` (optional) - The Heroku Inference API URL, defaults to https://inference.heroku.com/v1

2. Provision the Heroku Inference add-on:
   ```
   heroku addons:create heroku-inference:claude-3-sonnet
   ```

2. Deploy to Heroku:
   ```
   heroku create my-langchain-agent
   heroku buildpacks:set https://github.com/your-username/heroku-agent-buildpack.git
   git push heroku main
   ```

## API Endpoints

- `GET /` - Health check endpoint
- `POST /agent` - Run the agent
  ```json
  {
    "query": "What's the weather in San Francisco?",
    "conversation_id": "optional-conversation-id",
    "streaming": false
  }
  ```
- `DELETE /conversations/{conversation_id}` - Delete a conversation from memory

## Customization

To add more tools, modify the `tools` list in `app.py` and update the `agent.yaml` file to include your new tools.