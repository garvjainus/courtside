import random
import cv2
import torch
import os
from ultralytics import YOLO
import numpy as np
import shutil
from pathlib import Path
from deep_sort_realtime.deepsort_tracker import DeepSort 
import yaml


# Directory to store trained identities
DATASET_DIR = "dataset"
for split in ["train", "test", "valid"]:
    os.makedirs(f"{DATASET_DIR}/{split}/images", exist_ok=True)
    os.makedirs(f"{DATASET_DIR}/{split}/labels", exist_ok=True)

yolo_model = YOLO("yolov8n.pt")
# tracker = DeepSort(max_age=30, n_init=3, nn_budget=70)

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
            cv2.imwrite(image_path, frame)

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
    print(f"Processed {video_path} (Person {person_id})")


def process_videos(video_folder: str):
    videos = [f for f in os.listdir(video_folder) if f.endswith(('.mp4', '.avi', '.mov'))]
    nc = len(videos)
    names = [os.path.splitext(video)[0] for video in videos]
    data_yaml = {
        'train': './train',
        'val': './valid',
        'test': './test',
        'nc': nc,
        'names': names
    }

    with open('dataset/data.yaml', 'w') as f:
        yaml.dump(data_yaml, f, default_flow_style=False)


    
    for person_id, video in enumerate(videos):
        video_path = os.path.join(video_folder, video)
        extract_frames(video_path, person_id)

    print("all videos processed and labeled correctly")


process_videos("videos")

model = YOLO("yolov8n.pt")
model.train(data="dataset/data.yaml", epochs=10, imgsz=640, name="person_classifier")


'''
def train_person_tracking(video_path: str):
    """Detects persons in a video, extracts frames, and assigns unique IDs for tracking & re-ID training."""

    cap = cv2.VideoCapture(video_path)
    frame_id = 0

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        results = model(frame)
        detections = []
        
        for result in results:
            for box in result.boxes:
                if int(box.cls) == 0:
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    conf = box.conf[0].item()
                    detections.append(([x1, y1, x2, y2], conf, "person"))

        tracks = tracker.update_tracks(detections, frame=frame)

        for track in tracks:
            if track.is_confirmed():
                track_id = track.track_id
                x1, y1, x2, y2 = map(int, track.to_ltwh())

                person_crop = frame[y1:y2, x1:x2]
                person_folder = os.path.join(TRAINED_PERSON_DIR, f"person_{track_id}")
                os.makedirs(person_folder, exist_ok=True)
                cv2.imwrite(os.path.join(person_folder, f"frame_{frame_id}.jpg"), person_crop)

                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                cv2.putText(frame, f"ID: {track_id}", (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

        cv2.imshow("Tracking", frame)
        frame_id += 1

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

def prepare_data_for_yolo(directory: str):
    """Prepares dataset for YOLOv8 training with person-specific labels."""
    
    yaml_file_path = Path(directory) / 'data.yaml'
    
    data = {
        'train': str(yaml_file_path.parent / "train"),
        'val': str(yaml_file_path.parent / "val"),
        'names': {i: f"person_{i}" for i in range(len(os.listdir(directory)))}
    }

    with open(yaml_file_path, 'w') as yaml_file:
        yaml.dump(data, yaml_file)

    print("Dataset YAML file prepared at:", yaml_file_path)

def train_yolo_for_reid():
    """Train YOLOv8 to classify and re-identify people."""
    model = YOLO("yolov8n.pt")
    model.train(
        data="trained_persons/data.yaml",  
        imgsz=640,
        batch=16,
        epochs=10,
        name='person_reid'
    )

    model.export(format="onnx")
    model.export(format="tflite")
    model.export(format="coreml")


train_person_tracking("emi.MOV")
prepare_data_for_yolo("trained_persons")
train_yolo_for_reid()
'''