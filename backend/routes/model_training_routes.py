import os
from fastapi import APIRouter, UploadFile, File
from logic.model_training_logic import UPLOAD_DIR, DATASET_DIR, process_videos, train_model_logic, test_model_logic, reset_dataset_dir
import shutil
from typing import List

model_routes = APIRouter()

@model_routes.post("/upload_clips/")
async def upload_clips(files: List[UploadFile] = File(...)):
    uploaded_files = []
    for file in files:
        file_path = f"./live_frames/{file.filename}"
        with open(file_path, "wb") as f:
            f.write(await file.read())
        uploaded_files.append(file.filename)
    
    return {"uploaded_files": uploaded_files, "message": "Files uploaded successfully"}


@model_routes.post("/upload_game/")
async def upload_game(file: UploadFile = File(...)):
    file_path = f"./uploads/{file.filename}"  # Define the save path
    with open(file_path, "wb") as f:
        f.write(await file.read())  # Asynchronously write the file
    return {"filename": file.filename, "message": "File uploaded successfully"}

@model_routes.post("/upload_video/")
async def upload_video(file: UploadFile = File(...), player_name: str = "", player_team: str = ""):
    # Extract the file extension
    ext = os.path.splitext(file.filename)[1]
    # Create a new file name based on player_name and player_team
    new_filename = f"{player_name}_{player_team}{ext}"
    video_path = os.path.join(UPLOAD_DIR, new_filename)
    
    with open(video_path, "wb") as f:
        f.write(await file.read())
    reset_dataset_dir()
    
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
