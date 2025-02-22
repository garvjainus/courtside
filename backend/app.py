import os
import random
import cv2
import torch
import shutil
import yaml
from fastapi import FastAPI, File, UploadFile, HTTPException
from pathlib import Path
from pydantic import BaseModel
from typing import List
from ultralytics import YOLO
import coremltools as ct

app = FastAPI()

UPLOAD_DIR = "uploads"
DATASET_DIR = "dataset"
os.makedirs(UPLOAD_DIR, exist_ok=True)

yolo_model = YOLO("yolov8n.pt")

def extract_frames(video_path: str, person_id: int):
    cap = cv2.VideoCapture(video_path)
    frame_id = 0
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        
        dataset_split = random.choices(["train", "test", "valid"], [0.7, 0.15, 0.15])[0]
        image_filename = f"person_{person_id}_frame_{frame_id}.jpg"
        label_filename = f"person_{person_id}_frame_{frame_id}.txt"
        image_path = f"{DATASET_DIR}/{dataset_split}/images/{image_filename}"
        label_path = f"{DATASET_DIR}/{dataset_split}/labels/{label_filename}"

        cv2.imwrite(image_path, frame)

        height, width, _ = frame.shape
        results = yolo_model(frame)
        detections = results[0].boxes

        if len(detections) > 0:
            with open(label_path, "w") as f:
                for box in detections:
                    cls = int(box.cls.item())
                    if cls == 0:
                        x_min, y_min, x_max, y_max = box.xyxy[0].tolist()
                        x_center = ((x_min + x_max) / 2) / width
                        y_center = ((y_min + y_max) / 2) / height
                        norm_width = (x_max - x_min) / width
                        norm_height = (y_max - y_min) / height
                        f.write(f"{person_id} {x_center} {y_center} {norm_width} {norm_height}\n")
        frame_id += 1
    cap.release()

@app.post("/upload_video/")
async def upload_video(file: UploadFile = File(...), player_names: str = ""):
    video_path = os.path.join(UPLOAD_DIR, file.filename)
    with open(video_path, "wb") as f:
        f.write(await file.read())

    person_id = len(os.listdir(DATASET_DIR))
    extract_frames(video_path, person_id)
    
    if player_names:
        with open("player_names.txt", "a") as f:
            f.write(player_names + "\n")
    
    return {"message": f"Video {file.filename} uploaded and frames extracted."}

@app.post("/train_model/")
async def train_model():
    with open("player_names.txt", "r") as f:
        names = [line.strip() for line in f.readlines()]
    
    data_yaml = {
        'train': './train',
        'val': './valid',
        'test': './test',
        'nc': len(names),
        'names': names
    }
    
    with open('dataset/data.yaml', 'w') as f:
        yaml.dump(data_yaml, f, default_flow_style=False)
    
    yolo_model.train(data="dataset/data.yaml", epochs=10, imgsz=640, name="person_classifier")
    
    model_coreml = yolo_model.export(format="coreml")
    model_coreml.save("person_classifier.mlmodel")
    
    return {"message": "Model trained and exported to CoreML."}

@app.post("/test_model/")
async def test_model(file: UploadFile = File(...)):
    image_path = os.path.join(UPLOAD_DIR, file.filename)
    with open(image_path, "wb") as f:
        f.write(await file.read())

    results = yolo_model(image_path)
    detections = []
    for box in results[0].boxes:
        cls = int(box.cls.item())
        if cls == 0:
            x_min, y_min, x_max, y_max = box.xyxy[0].tolist()
            detections.append({
                "class_id": cls,
                "bounding_box": [x_min, y_min, x_max, y_max],
                "confidence": box.conf[0].item()
            })
    
    return {"detections": detections}

# run with: uvicorn main:app --reload