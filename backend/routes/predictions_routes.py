import os
import json
from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.concurrency import run_in_threadpool
from logic.predictions_logic import process_game  # our unified video processing function with stat tracking

predictions_routes = APIRouter()

@predictions_routes.post("/predict_video/")
async def predict_video(file: UploadFile = File(...)):
    """
    Receives a video file, runs the unified prediction logic to generate game events
    and player stats (including possession, assists, shots, and rebounds), and returns
    the results as JSON.
    """
    # Create the uploads directory and save the video file.
    upload_dir = "uploads"
    os.makedirs(upload_dir, exist_ok=True)
    video_path = os.path.join(upload_dir, file.filename)
    
    try:
        contents = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail="Failed to read uploaded file") from e

    try:
        with open(video_path, "wb") as f:
            f.write(contents)
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to save uploaded file") from e

    # Process the video using the unified process_game function in a thread pool.
    try:
        results = await run_in_threadpool(process_game, video_path)
    except Exception as e:
        raise HTTPException(status_code=500, detail="Error processing video") from e

    # Optionally, save the output to a JSON file.
    output_dir = "outputs"
    os.makedirs(output_dir, exist_ok=True)
    output_json_path = os.path.join(output_dir, f"{file.filename}.json")
    try:
        with open(output_json_path, "w") as f:
            json.dump(results, f)
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to save output JSON") from e

    return results
