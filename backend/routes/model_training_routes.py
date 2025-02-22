import os
from fastapi import APIRouter, UploadFile, File
from logic.model_training_logic import UPLOAD_DIR, DATASET_DIR, process_video_upload, train_model_logic, test_model_logic

model_routes = APIRouter()



@model_routes.post("/upload_video/")
async def upload_video(file: UploadFile = File(...), player_names: str = ""):
    video_path = os.path.join(UPLOAD_DIR, file.filename)
    with open(video_path, "wb") as f:
        f.write(await file.read())
    
    process_video_upload(video_path, player_names)
    return {"message": f"Video {file.filename} uploaded and frames extracted."}

@model_routes.post("/train_model/")
async def train_model():
    train_model_logic()
    return {"message": "Model trained and exported to CoreML."}

@model_routes.post("/test_model/")
async def test_model(file: UploadFile = File(...)):
    image_path = os.path.join(UPLOAD_DIR, file.filename)
    with open(image_path, "wb") as f:
        f.write(await file.read())
    
    detections = test_model_logic(image_path)
    return {"detections": detections}
