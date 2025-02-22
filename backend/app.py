from fastapi import FastAPI
from routes.model_training_routes import model_routes

app = FastAPI()

# Include the router from routes.py
app.include_router(model_routes)

# To run the app use:
# uvicorn app:app --reload
