import os
import json
from fastapi import APIRouter, UploadFile, File
from logic.predictions_logic import process_game  # updated unified video processing function

predictions_routes = APIRouter()

@predictions_routes.post("/predict_video/")
async def predict_video(file: UploadFile = File(...)):
    """
    Receives a video, runs the unified prediction logic to generate game events and player stats,
    and returns the results as JSON.
    """
    # Save the uploaded video.
    video_path = f"uploads/{file.filename}"
    os.makedirs("uploads", exist_ok=True)
    with open(video_path, "wb") as f:
        f.write(await file.read())
    
    # Process the video using the new process_game function.
    results = process_game(video_path)
    
    # Optionally, save the output to a JSON file.
    output_json_path = f"outputs/{file.filename}.json"
    os.makedirs("outputs", exist_ok=True)
    with open(output_json_path, "w") as f:
        json.dump(results, f)
    
    return results
