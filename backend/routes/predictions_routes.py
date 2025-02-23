import os
import json
from fastapi import APIRouter, UploadFile, File
from logic.predictions_logic import process_video_and_generate_events

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
    
    # Define the output path for the JSON file.
    output_json_path = f"outputs/{file.filename}.json"
    os.makedirs("outputs", exist_ok=True)
    
    # Process the video and generate events using our unified logic.
    process_video_and_generate_events(video_path, window_size=10, frame_rate=30.0, output_json_path=output_json_path)
    
    # Load and return the output JSON.
    with open(output_json_path, "r") as f:
        output_data = json.load(f)
    
    return output_data
