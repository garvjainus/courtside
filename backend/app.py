from fastapi import FastAPI
from routes.model_training_routes import model_routes
from routes.predictions_routes import predictions_routes

app = FastAPI()

# Include the router from routes.py
app.include_router(model_routes)
app.include_router(predictions_routes)

# To run the app use:
# uvicorn app:app --reload
