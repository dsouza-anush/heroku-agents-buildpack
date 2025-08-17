#!/usr/bin/env bash
# Resource provisioning helper functions for Heroku Agent Buildpack

# Provision Heroku Inference for LLM API
provision_inference() {
    local config_file=$1
    local build_dir=$2
    local enabled=true
    local model="claude-3-sonnet"
    
    # Check if a specific model is specified in config
    if [[ "$config_file" == *".yaml" ]]; then
        if grep -q "model:" "$config_file"; then
            model=$(grep "model:" "$config_file" | head -1 | awk '{print $2}' | tr -d '"'"'"')
        fi
    else
        # JSON parsing (simplified)
        if grep -q "\"model\":" "$config_file"; then
            model=$(grep "\"model\":" "$config_file" | head -1 | awk '{print $2}' | tr -d '"'"'",')
        fi
    fi
    
    puts_step "Heroku Inference enabled with model: $model, would provision heroku-inference:$model"
    # In a real buildpack, this would use the Heroku API to provision Inference
    # For now, we'll just generate the necessary code to connect to Inference API
    
    # Create a helper file for Inference API
    mkdir -p "$build_dir/agent_helpers"
    cat > "$build_dir/agent_helpers/inference.py" << 'EOF'
import os

def get_inference_config():
    """Get configuration for Heroku Inference API."""
    api_key = os.getenv("HEROKU_API_KEY")
    if not api_key:
        raise ValueError("No HEROKU_API_KEY found in environment variables")
    
    inference_url = os.getenv("HEROKU_INFERENCE_URL", "https://inference.heroku.com/v1")
    model = os.getenv("AGENT_MODEL", "claude-3-sonnet")
    
    return {
        "api_key": api_key,
        "base_url": inference_url,
        "model": model
    }
EOF
    
    # Add a note to .profile.d to configure Inference environment
    mkdir -p "$build_dir/.profile.d"
    cat > "$build_dir/.profile.d/inference_setup.sh" << 'EOF'
#!/usr/bin/env bash
# Configure Heroku Inference environment variables
if [ -n "$HEROKU_INFERENCE_URL" ]; then
    echo "Heroku Inference URL already set to: $HEROKU_INFERENCE_URL"
else
    echo "Setting default Heroku Inference URL"
    export HEROKU_INFERENCE_URL="https://inference.heroku.com/v1"
fi

# Check if HEROKU_API_KEY is set (needed for Inference API)
if [ -z "$HEROKU_API_KEY" ]; then
    echo "WARNING: HEROKU_API_KEY not set. Please set it using: heroku config:set HEROKU_API_KEY=your-api-key"
fi
EOF
    chmod +x "$build_dir/.profile.d/inference_setup.sh"
    puts_step "Created Inference API setup in .profile.d/"
}

# Provision Redis for agent memory if needed
provision_redis() {
    local config_file=$1
    local build_dir=$2
    local enabled=false
    local plan="mini"
    
    # Check if Redis is enabled in config
    if [[ "$config_file" == *".yaml" ]]; then
        if grep -q "memory:" "$config_file" && grep -q "enabled: true" "$config_file"; then
            enabled=true
            # Try to extract plan if specified
            if grep -q "plan:" "$config_file"; then
                plan=$(grep "plan:" "$config_file" | head -1 | awk '{print $2}' | tr -d '"'"'"')
            fi
        fi
    else
        # JSON parsing (simplified)
        if grep -q "\"memory\"" "$config_file" && grep -q "\"enabled\": true" "$config_file"; then
            enabled=true
            # Try to extract plan if specified
            if grep -q "\"plan\":" "$config_file"; then
                plan=$(grep "\"plan\":" "$config_file" | head -1 | awk '{print $2}' | tr -d '"'"'",')
            fi
        fi
    fi
    
    if [ "$enabled" = true ]; then
        puts_step "Redis memory storage enabled, would provision heroku-redis:$plan"
        # In a real buildpack, this would use the Heroku API to provision Redis
        # For now, we'll just generate the necessary code to connect to Redis
        
        # Create a Redis connection helper
        mkdir -p "$build_dir/agent_helpers"
        cat > "$build_dir/agent_helpers/redis_memory.py" << 'EOF'
import os
import redis
from urllib.parse import urlparse

def get_redis_connection():
    """Get a Redis connection from REDIS_URL or HEROKU_REDIS_URL env variables."""
    redis_url = os.getenv("REDIS_URL") or os.getenv("HEROKU_REDIS_URL")
    if not redis_url:
        raise ValueError("No Redis URL found in environment variables")
    
    # Parse the Redis URL
    parsed_url = urlparse(redis_url)
    
    # Connect to Redis
    return redis.Redis(
        host=parsed_url.hostname,
        port=parsed_url.port,
        username=parsed_url.username,
        password=parsed_url.password,
        ssl=True if parsed_url.scheme == "rediss" else False,
        decode_responses=True
    )

class RedisMemory:
    """Simple memory class using Redis."""
    def __init__(self, prefix="agent_memory:", ttl=86400):
        self.redis = get_redis_connection()
        self.prefix = prefix
        self.ttl = ttl  # Default TTL of 24 hours
    
    def save(self, key, value, ttl=None):
        """Save a value to Redis with an optional TTL."""
        full_key = f"{self.prefix}{key}"
        self.redis.set(full_key, value, ex=ttl or self.ttl)
    
    def load(self, key):
        """Load a value from Redis."""
        full_key = f"{self.prefix}{key}"
        return self.redis.get(full_key)
    
    def delete(self, key):
        """Delete a value from Redis."""
        full_key = f"{self.prefix}{key}"
        self.redis.delete(full_key)
EOF
        
        # Add Redis dependency to requirements.txt
        if ! grep -q "redis" "$build_dir/requirements.txt"; then
            echo "redis>=4.5.1" >> "$build_dir/requirements.txt"
            puts_step "Added Redis dependency to requirements.txt"
        fi
    fi
}

# Provision Postgres with pgvector for vector storage if needed
provision_postgres() {
    local config_file=$1
    local build_dir=$2
    local enabled=false
    local plan="mini"
    local extensions=""
    
    # Check if Postgres is enabled in config
    if [[ "$config_file" == *".yaml" ]]; then
        if grep -q "vector_db:" "$config_file" && grep -q "enabled: true" "$config_file"; then
            enabled=true
            # Try to extract plan if specified
            if grep -q "plan:" "$config_file"; then
                plan=$(grep "plan:" "$config_file" | head -1 | awk '{print $2}' | tr -d '"'"'"')
            fi
            # Check for pgvector extension
            if grep -q "extensions:" "$config_file" && grep -q "pgvector" "$config_file"; then
                extensions="pgvector"
            fi
        fi
    else
        # JSON parsing (simplified)
        if grep -q "\"vector_db\"" "$config_file" && grep -q "\"enabled\": true" "$config_file"; then
            enabled=true
            # Try to extract plan if specified
            if grep -q "\"plan\":" "$config_file"; then
                plan=$(grep "\"plan\":" "$config_file" | head -1 | awk '{print $2}' | tr -d '"'"'",')
            fi
            # Check for pgvector extension
            if grep -q "\"extensions\":" "$config_file" && grep -q "\"pgvector\"" "$config_file"; then
                extensions="pgvector"
            fi
        fi
    fi
    
    if [ "$enabled" = true ]; then
        puts_step "Postgres vector database enabled, would provision heroku-postgresql:$plan"
        # In a real buildpack, this would use the Heroku API to provision Postgres
        # For now, we'll just generate the necessary code to connect to Postgres
        
        # Create a Postgres connection helper
        mkdir -p "$build_dir/agent_helpers"
        cat > "$build_dir/agent_helpers/postgres_db.py" << 'EOF'
import os
import sqlalchemy
from sqlalchemy import create_engine, Column, Integer, String, Float, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

def get_postgres_engine():
    """Get a SQLAlchemy engine from DATABASE_URL env variable."""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise ValueError("No DATABASE_URL found in environment variables")
    
    # Handle special case for Heroku postgres://
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
    
    # Create engine
    return create_engine(database_url)

# Base class for SQLAlchemy models
Base = declarative_base()

# Example vector store model
class VectorEntry(Base):
    """Example model for storing vectors."""
    __tablename__ = "vector_entries"
    
    id = Column(Integer, primary_key=True)
    content_id = Column(String(255), nullable=False, index=True)
    content = Column(Text, nullable=False)
    embedding = Column(sqlalchemy.JSON, nullable=True)
    
    def __repr__(self):
        return f"<VectorEntry(id={self.id}, content_id='{self.content_id}')>"

def init_db():
    """Initialize the database schema."""
    engine = get_postgres_engine()
    Base.metadata.create_all(engine)
    return engine

def get_session():
    """Get a SQLAlchemy session."""
    engine = get_postgres_engine()
    Session = sessionmaker(bind=engine)
    return Session()
EOF
        
        # Add PostgreSQL dependencies to requirements.txt
        if ! grep -q "sqlalchemy" "$build_dir/requirements.txt"; then
            echo "sqlalchemy>=2.0.0" >> "$build_dir/requirements.txt"
            echo "psycopg2-binary>=2.9.5" >> "$build_dir/requirements.txt"
            puts_step "Added PostgreSQL dependencies to requirements.txt"
        fi
        
        # If pgvector is requested, add setup instructions
        if [ "$extensions" = "pgvector" ]; then
            puts_step "pgvector extension requested, would enable extension"
            # Add pgvector dependency
            if ! grep -q "pgvector" "$build_dir/requirements.txt"; then
                echo "pgvector>=0.2.0" >> "$build_dir/requirements.txt"
                puts_step "Added pgvector dependency to requirements.txt"
            fi
            
            # Create pgvector setup helper
            cat > "$build_dir/agent_helpers/pgvector_setup.py" << 'EOF'
"""Helper script to initialize pgvector extension in Postgres."""
import os
import sys
import sqlalchemy
from sqlalchemy import text

def setup_pgvector():
    """Set up pgvector extension in Postgres."""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        print("No DATABASE_URL found in environment variables")
        sys.exit(1)
    
    # Handle special case for Heroku postgres://
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
    
    # Create engine
    engine = sqlalchemy.create_engine(database_url)
    
    # Create extension
    with engine.connect() as conn:
        try:
            conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector;"))
            conn.commit()
            print("pgvector extension created successfully")
        except Exception as e:
            print(f"Error creating pgvector extension: {e}")
            sys.exit(1)

if __name__ == "__main__":
    setup_pgvector()
EOF
            
            # Create a script to run on release phase
            mkdir -p "$build_dir/.profile.d"
            cat > "$build_dir/.profile.d/pgvector_setup.sh" << 'EOF'
#!/usr/bin/env bash
# Set up pgvector extension on release
python -m agent_helpers.pgvector_setup
EOF
            chmod +x "$build_dir/.profile.d/pgvector_setup.sh"
            puts_step "Created pgvector setup script in .profile.d/"
        fi
    fi
}

# Provision all required resources
provision_resources() {
    local config_file=$1
    local build_dir=$2
    
    puts_step "Checking for resource provisioning requirements"
    
    # Provision Heroku Inference for LLM API
    provision_inference "$config_file" "$build_dir"
    
    # Provision Redis if needed
    provision_redis "$config_file" "$build_dir"
    
    # Provision Postgres if needed
    provision_postgres "$config_file" "$build_dir"
}