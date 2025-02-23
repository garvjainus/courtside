from fastapi import UploadFile, File
import cv2
import torch
import numpy as np
import coremltools as ct
from ultralytics import YOLO


def process_frame(image_path: str):
    """Runs CoreML model on an image and predicts user ID."""
    trained_model = ct.models.MLModel("person_classifier.mlmodel")
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
    """Processes video, detects ball, rim, and person, and predicts user ID if a person is detected."""
    yolo_model = YOLO("best.pt")

    cap = cv2.VideoCapture(video_path)
    frame_results = []
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        
        results = yolo_model(frame)
        frame_detections = {"ball": [], "rim": [], "user_id": []}
        
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
            elif cls == 2:  # rim detected
                frame_detections["rim"].append({
                    "bounding_box": [x_min, y_min, x_max, y_max],
                    "confidence": confidence
                })
        
        frame_results.append(frame_detections)
    
    cap.release()
    return frame_results

def determine_possession(frame_detections):
    """Determines which user has possession of the ball."""
    for frame in frame_detections:
        for ball in frame["ball"]:
            ball_box = ball["bounding_box"]
            for user in frame["user_id"]:
                user_box = user["bounding_box"]
                if is_near(ball_box, user_box):
                    return user["user_id"]
    return None

def detect_passes(frame_detections):
    """Detects when a pass is made."""
    passes = []
    prev_possession = None
    for frame in frame_detections:
        current_possession = determine_possession([frame])
        if prev_possession and current_possession and prev_possession != current_possession:
            passes.append((prev_possession, current_possession))
        prev_possession = current_possession
    return passes

def detect_shots(frame_detections):
    """Detects when a shot is taken."""
    shots = []
    for frame in frame_detections:
        for ball in frame["ball"]:
            ball_box = ball["bounding_box"]
            if is_near_goal(ball_box, frame["rim"]):
                shots.append(ball_box)
    return shots

def detect_shot_results(frame_detections):
    """Determines if a shot is made or missed."""
    shot_results = []
    for shot in detect_shots(frame_detections):
        if is_goal(shot):
            shot_results.append("Made")
        else:
            shot_results.append("Missed")
    return shot_results

def is_near(box1, box2):
    """Helper function to check proximity between two bounding boxes."""
    x1_min, y1_min, x1_max, y1_max = box1
    x2_min, y2_min, x2_max, y2_max = box2
    return abs(x1_min - x2_min) < 30 and abs(y1_min - y2_min) < 30

def is_near_goal(ball_box, rim_boxes):
    """Checks if the ball is near the goal."""
    for rim in rim_boxes:
        if is_near(ball_box, rim["bounding_box"]):
            return True
    return False

def is_goal(shot_box):
    """Determines if a shot results in a goal."""
    return shot_box[1] < 50  # Assume goal is in the top area of the frame
