from fastapi import UploadFile, File
import cv2
import torch
import numpy as np
import coremltools as ct
from ultralytics import YOLO

# PERSON CLASSIFIER
trained_model = ct.models.MLModel("person_classifier.mlmodel")
# PERSON BALL RIM OBJECT DETECTOR
yolo_model = YOLO("best.pt")

def process_frame(image_path: str):
    """Runs CoreML model on an image and predicts user ID."""
    image = cv2.imread(image_path)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    
    results = trained_model.predict({"image": image})
    detections = []
    
    for result in results["outputs"]:
        cls = int(result["class"])
        x_min, y_min, x_max, y_max = result["bbox"]
        confidence = result["confidence"]
        detections.append({
            "user_id": cls,  # Using class ID as the unique user ID
            "bounding_box": [x_min, y_min, x_max, y_max],
            "confidence": confidence
        })
    
    return detections

def process_video(video_path: str):
    """Processes video, detects ball, rink, and person, and predicts user ID if a person is detected."""
    cap = cv2.VideoCapture(video_path)
    frame_results = []
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        
        results = yolo_model(frame)
        frame_detections = {"ball": [], "rink": [], "user_id": []}
        
        for box in results[0].boxes:
            cls = int(box.cls.item())
            x_min, y_min, x_max, y_max = box.xyxy[0].tolist()
            confidence = box.conf[0].item()
            
            if cls == 1:  # Person detected
                image_path = "temp_frame.jpg"
                cv2.imwrite(image_path, frame)
                user_detections = process_frame(image_path)
                frame_detections["user_id"].extend(user_detections)
            elif cls == 0:  # Ball detected
                frame_detections["ball"].append({
                    "bounding_box": [x_min, y_min, x_max, y_max],
                    "confidence": confidence
                })
            elif cls == 2:  # Rink detected
                frame_detections["rink"].append({
                    "bounding_box": [x_min, y_min, x_max, y_max],
                    "confidence": confidence
                })
        
        frame_results.append(frame_detections)
    
    cap.release()
    return frame_results

@app.post("/predict_video/")
async def predict_video(file: UploadFile = File(...)):
    """Receives a video, runs YOLO prediction, and returns detections for ball, rink, and user ID."""
    video_path = f"uploads/{file.filename}"
    with open(video_path, "wb") as f:
        f.write(await file.read())
    
    detections = process_video(video_path)
    
    return {"detections": detections}
