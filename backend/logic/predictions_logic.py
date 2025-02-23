from fastapi import UploadFile, File
import cv2
import torch
import numpy as np
import coremltools as ct
from ultralytics import YOLO
from PIL import Image

# def process_frame(image_path: str):
#     """Runs CoreML model on an image and predicts user ID."""
#     trained_model = ct.models.MLModel("../runs/detect/person_classifier10/weights/best.mlpackage/Data/com.apple.CoreML/model.mlmodel")
#     # image = cv2.imread(image_path)
#     # image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

#     image = cv2.imread(image_path)  # BGR format
#     image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)  # Convert to RGB
#     image = Image.fromarray(image)  # Convert to PIL Image
    
#     input_description = trained_model.get_spec().description.input
#     print(input_description)

#     # Now, pass the PIL image to CoreML
#     results = trained_model.predict({"image": image})
    
#     detections = []
    
#     for result in results["outputs"]:
#         cls = int(result["class"])
#         x_min, y_min, x_max, y_max = result["bbox"]
#         confidence = result["confidence"]
#         detections.append({
#             "user_id": cls,  # Using class ID as the unique user ID
#             "bounding_box": [x_min, y_min, x_max, y_max],
#             "confidence": confidence
#         })
    
#     return detections

model = YOLO('backend/runs/detect/person_classifier/weights/best.pt')
yolo_model = YOLO("backend/best.pt")


def process_frame(image: str):
    """Runs YOLO model on an image and predicts user ID."""
    
    # Read and preprocess the image
    # image = cv2.imread(image_path)  # Read image (BGR format)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)  # Convert to RGB
    
    # Run inference using YOLO
    results = model(image)  # YOLO automatically resizes the image if needed
    
    detections = []
    
    for result in results:
        for box in result.boxes:
            print("working")
            x_min, y_min, x_max, y_max = box.xyxy[0].tolist()  # Bounding box
            confidence = box.conf[0].item()  # Confidence score
            cls = int(box.cls[0].item())  # Class ID
            
            detections.append({
                "user_id": cls,  # Using class ID as the unique user ID
                "bounding_box": [x_min, y_min, x_max, y_max],
                "confidence": confidence
            })
    
    return detections

def process_video(video_path: str):
    """Processes video, detects ball, rim, and person, and predicts user ID if a person is detected."""

    cap = cv2.VideoCapture(video_path)
    frame_results = []
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        
        results = yolo_model(frame)
        frame_detections = {"ball": [], "rim": [], "user_id": []}
        
        detected_classes = [int(box.cls.item()) for box in results[0].boxes]
        print("Detected classes:", detected_classes)

        for box in results[0].boxes:
            cls = int(box.cls.item())
            x_min, y_min, x_max, y_max = box.xyxy[0].tolist()
            confidence = box.conf[0].item()

            print(f"Detected class {cls} with confidence {confidence}")
            
            if cls == 1:  # Person detected
                user_detections = process_frame(frame)  # Pass frame directly
                # user_ids = [detection["user_id"] for detection in user_detections]  # Extract user IDs
                # frame_detections["user_id"].extend(user_ids)
                # frame_detections["user_id"].append(user_detections)
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
