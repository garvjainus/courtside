import os
from fastapi import APIRouter, UploadFile, File
from logic.model_training_logic import UPLOAD_DIR, DATASET_DIR, process_videos, train_model_logic, test_model_logic

model_routes = APIRouter()



@model_routes.post("/upload_video/")
async def upload_video(file: UploadFile = File(...), player_name: str = "", player_team: str = ""):
    # Extract the file extension
    ext = os.path.splitext(file.filename)[1]
    # Create a new file name based on player_name and player_team
    new_filename = f"{player_name}_{player_team}{ext}"
    video_path = os.path.join(UPLOAD_DIR, new_filename)
    
    with open(video_path, "wb") as f:
        f.write(await file.read())
    
    return {"filename": new_filename}


@model_routes.post("/train_model/")
async def train_model():
    process_videos(UPLOAD_DIR)
    train_model_logic()
    return {"message": "Model trained and exported to CoreML."}

@model_routes.post("/test_model/")
async def test_model(file: UploadFile = File(...)):
    image_path = os.path.join(UPLOAD_DIR, file.filename)
    with open(image_path, "wb") as f:
        f.write(await file.read())
    
    detections = test_model_logic(image_path)
    return {"detections": detections}
