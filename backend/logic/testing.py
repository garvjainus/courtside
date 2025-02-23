import cv2
from ultralytics import YOLO

model = YOLO('runs/detect/person_classifier/weights/best.pt')
yolo_model = YOLO("best.pt")

def process_frame(image: str):
    """Runs YOLO model on an image and predicts user ID."""
    
    # Read and preprocess the image
    # image = cv2.imread(image_path)  # Read image (BGR format)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)  # Convert to RGB
    
    # Run inference using YOLO
    results = model(image)  # YOLO automatically resizes the image if needed
    
    detections = []
    
    for result in results:
        for box in result.boxes:
            print("working")
            x_min, y_min, x_max, y_max = box.xyxy[0].tolist()  # Bounding box
            confidence = box.conf[0].item()  # Confidence score
            cls = int(box.cls[0].item())  # Class ID
            
            detections.append({
                "user_id": cls,  # Using class ID as the unique user ID
                "bounding_box": [x_min, y_min, x_max, y_max],
                "confidence": confidence
            })
    
    return detections

def process_video_with_labels(video_path: str, output_path: str):
    """Processes video, detects ball, rim, and person, predicts user ID, and saves the output video with labels while displaying it in real-time."""
    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        print(f"Error: Could not open video file '{video_path}'")
 frame_width = int(cap.get(3))
    frame_height = int(cap.get(4))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')  # Codec for MP4 format
    out = cv2.VideoWriter(output_path, fourcc, fps, (frame_width, frame_height))
    
    frame_results = []
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        
        results = yolo_model(frame)
        frame_detections = {"ball": [], "rim": [], "user_id": []}
        
        for box in results[0].boxes:
            cls = int(box.cls.item())
            x_min, y_min, x_max, y_max = map(int, box.xyxy[0].tolist())
            confidence = box.conf[0].item()
            
            label = ""
            color = (0, 255, 0)  # Default green color
            
            if cls == 1:  # Person detected
                user_detections = process_frame(frame)  # Pass frame directly
                frame_detections["user_id"].extend(user_detections)
                label = f"Person (User ID: {user_detections})"
                color = (255, 0, 0)  # Blue for person
            elif cls == 0:  # Ball detected
                frame_detections["ball"].append({
                    "bounding_box": [x_min, y_min, x_max, y_max],
                    "confidence": confidence
                })
                label = "Ball"
                color = (0, 0, 255)  # Red for ball
            elif cls == 2:  # Rim detected
                frame_detections["rim"].append({
                    "bounding_box": [x_min, y_min, x_max, y_max],
                    "confidence": confidence
                })
                label = "Rim"
                color = (0, 255, 255)  # Yellow for rim
 # Draw bounding box and label on frame
            cv2.rectangle(frame, (x_min, y_min), (x_max, y_max), color, 2)
            cv2.putText(frame, label, (x_min, y_min - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
        
        frame_results.append(frame_detections)
        out.write(frame)
        
        # Display the frame while processing
        cv2.imshow('Video Processing', frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
    
    cap.release()
    out.release()
    cv2.destroyAllWindows()
    return frame_results

import os
video_path = os.path.abspath("uploads/bas.mp4")

process_video_with_labels(video_path, "answer.mp4")