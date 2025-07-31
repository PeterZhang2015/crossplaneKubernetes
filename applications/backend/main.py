"""
FastAPI backend service with PostgreSQL integration
Demonstrates the complete application stack for the Crossplane Kubernetes automation platform
"""

import os
import logging
from datetime import datetime
from typing import List, Optional
from contextlib import asynccontextmanager

import asyncpg
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import uvicorn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Database configuration from environment variables
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://dbadmin:password@localhost:5432/appdb"
)

# Application configuration
APP_NAME = os.getenv("APP_NAME", "Crossplane Test API")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

# Global database connection pool
db_pool = None

# Pydantic models
class HealthResponse(BaseModel):
    status: str = "healthy"
    timestamp: datetime
    version: str
    environment: str
    database_status: str

class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    priority: str = Field(default="medium", regex="^(low|medium|high)$")

class TaskUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    priority: Optional[str] = Field(None, regex="^(low|medium|high)$")
    completed: Optional[bool] = None

class Task(BaseModel):
    id: int
    title: str
    description: Optional[str]
    priority: str
    completed: bool
    created_at: datetime
    updated_at: datetime

class TaskList(BaseModel):
    tasks: List[Task]
    total: int
    page: int
    per_page: int

# Database functions
async def init_db():
    """Initialize database connection pool and create tables"""
    global db_pool
    try:
        db_pool = await asyncpg.create_pool(
            DATABASE_URL,
            min_size=1,
            max_size=10,
            command_timeout=60
        )
        
        # Create tables if they don't exist
        async with db_pool.acquire() as conn:
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(200) NOT NULL,
                    description TEXT,
                    priority VARCHAR(10) DEFAULT 'medium',
                    completed BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );
                
                CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
                CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed);
                CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);
            """)
            
        logger.info("Database initialized successfully")
        
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise

async def close_db():
    """Close database connection pool"""
    global db_pool
    if db_pool:
        await db_pool.close()
        logger.info("Database connection pool closed")

async def get_db_connection():
    """Get database connection from pool"""
    if not db_pool:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection not available"
        )
    return db_pool

# Application lifespan management
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info(f"Starting {APP_NAME} v{APP_VERSION} in {ENVIRONMENT} environment")
    await init_db()
    yield
    # Shutdown
    await close_db()
    logger.info("Application shutdown complete")

# FastAPI application
app = FastAPI(
    title=APP_NAME,
    version=APP_VERSION,
    description="Test API for Crossplane Kubernetes automation platform",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint
@app.get("/health", response_model=HealthResponse)
async def health_check(db_pool=Depends(get_db_connection)):
    """Health check endpoint for Kubernetes probes"""
    db_status = "unknown"
    
    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        db_status = "healthy"
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        db_status = "unhealthy"
    
    return HealthResponse(
        timestamp=datetime.utcnow(),
        version=APP_VERSION,
        environment=ENVIRONMENT,
        database_status=db_status
    )

# Readiness probe
@app.get("/ready")
async def readiness_check(db_pool=Depends(get_db_connection)):
    """Readiness probe for Kubernetes"""
    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        return {"status": "ready"}
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service not ready"
        )

# Liveness probe
@app.get("/live")
async def liveness_check():
    """Liveness probe for Kubernetes"""
    return {"status": "alive"}

# Metrics endpoint
@app.get("/metrics")
async def metrics(db_pool=Depends(get_db_connection)):
    """Basic metrics endpoint"""
    try:
        async with db_pool.acquire() as conn:
            total_tasks = await conn.fetchval("SELECT COUNT(*) FROM tasks")
            completed_tasks = await conn.fetchval("SELECT COUNT(*) FROM tasks WHERE completed = TRUE")
            
        return {
            "total_tasks": total_tasks,
            "completed_tasks": completed_tasks,
            "pending_tasks": total_tasks - completed_tasks,
            "completion_rate": (completed_tasks / total_tasks * 100) if total_tasks > 0 else 0
        }
    except Exception as e:
        logger.error(f"Metrics collection failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to collect metrics"
        )

# Task CRUD endpoints
@app.post("/tasks", response_model=Task, status_code=status.HTTP_201_CREATED)
async def create_task(task: TaskCreate, db_pool=Depends(get_db_connection)):
    """Create a new task"""
    try:
        async with db_pool.acquire() as conn:
            row = await conn.fetchrow("""
                INSERT INTO tasks (title, description, priority)
                VALUES ($1, $2, $3)
                RETURNING id, title, description, priority, completed, created_at, updated_at
            """, task.title, task.description, task.priority)
            
        return Task(**dict(row))
    except Exception as e:
        logger.error(f"Failed to create task: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create task"
        )

@app.get("/tasks", response_model=TaskList)
async def get_tasks(
    page: int = 1,
    per_page: int = 10,
    priority: Optional[str] = None,
    completed: Optional[bool] = None,
    db_pool=Depends(get_db_connection)
):
    """Get tasks with pagination and filtering"""
    try:
        offset = (page - 1) * per_page
        
        # Build query with filters
        where_conditions = []
        params = []
        param_count = 0
        
        if priority:
            param_count += 1
            where_conditions.append(f"priority = ${param_count}")
            params.append(priority)
            
        if completed is not None:
            param_count += 1
            where_conditions.append(f"completed = ${param_count}")
            params.append(completed)
        
        where_clause = "WHERE " + " AND ".join(where_conditions) if where_conditions else ""
        
        async with db_pool.acquire() as conn:
            # Get total count
            count_query = f"SELECT COUNT(*) FROM tasks {where_clause}"
            total = await conn.fetchval(count_query, *params)
            
            # Get tasks
            tasks_query = f"""
                SELECT id, title, description, priority, completed, created_at, updated_at
                FROM tasks {where_clause}
                ORDER BY created_at DESC
                LIMIT ${param_count + 1} OFFSET ${param_count + 2}
            """
            params.extend([per_page, offset])
            
            rows = await conn.fetch(tasks_query, *params)
            tasks = [Task(**dict(row)) for row in rows]
        
        return TaskList(
            tasks=tasks,
            total=total,
            page=page,
            per_page=per_page
        )
    except Exception as e:
        logger.error(f"Failed to get tasks: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve tasks"
        )

@app.get("/tasks/{task_id}", response_model=Task)
async def get_task(task_id: int, db_pool=Depends(get_db_connection)):
    """Get a specific task by ID"""
    try:
        async with db_pool.acquire() as conn:
            row = await conn.fetchrow("""
                SELECT id, title, description, priority, completed, created_at, updated_at
                FROM tasks WHERE id = $1
            """, task_id)
            
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Task not found"
            )
            
        return Task(**dict(row))
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get task {task_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve task"
        )

@app.put("/tasks/{task_id}", response_model=Task)
async def update_task(task_id: int, task_update: TaskUpdate, db_pool=Depends(get_db_connection)):
    """Update a task"""
    try:
        # Build update query dynamically
        update_fields = []
        params = []
        param_count = 0
        
        if task_update.title is not None:
            param_count += 1
            update_fields.append(f"title = ${param_count}")
            params.append(task_update.title)
            
        if task_update.description is not None:
            param_count += 1
            update_fields.append(f"description = ${param_count}")
            params.append(task_update.description)
            
        if task_update.priority is not None:
            param_count += 1
            update_fields.append(f"priority = ${param_count}")
            params.append(task_update.priority)
            
        if task_update.completed is not None:
            param_count += 1
            update_fields.append(f"completed = ${param_count}")
            params.append(task_update.completed)
        
        if not update_fields:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No fields to update"
            )
        
        update_fields.append("updated_at = NOW()")
        params.append(task_id)
        
        async with db_pool.acquire() as conn:
            row = await conn.fetchrow(f"""
                UPDATE tasks 
                SET {', '.join(update_fields)}
                WHERE id = ${param_count + 1}
                RETURNING id, title, description, priority, completed, created_at, updated_at
            """, *params)
            
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Task not found"
            )
            
        return Task(**dict(row))
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update task {task_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update task"
        )

@app.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(task_id: int, db_pool=Depends(get_db_connection)):
    """Delete a task"""
    try:
        async with db_pool.acquire() as conn:
            result = await conn.execute("DELETE FROM tasks WHERE id = $1", task_id)
            
        if result == "DELETE 0":
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Task not found"
            )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete task {task_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete task"
        )

# Error handlers
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"}
    )

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=ENVIRONMENT == "development",
        log_level="info"
    )