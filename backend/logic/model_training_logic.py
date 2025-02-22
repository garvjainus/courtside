import os
import random
import cv2
import yaml
from ultralytics import YOLO
import shutil

# Define directories and create necessary folders

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

current_file_dir = os.path.dirname(os.path.abspath(__file__))
# Get the parent directory of 'logic' (i.e., the 'backend' directory)
backend_dir = os.path.dirname(current_file_dir)
# Now join with "uploads"
UPLOAD_DIR = os.path.join(backend_dir, "uploads")
DATASET_DIR = os.path.join(backend_dir, "dataset")

os.makedirs(UPLOAD_DIR, exist_ok=True)

print("UPLOAD_DIR =", UPLOAD_DIR)

print("DATASET_DIR =", DATASET_DIR)

# Load the YOLO model once so it can be reused
yolo_model = YOLO("yolov8n.pt")

def extract_frames(video_path: str, person_id: int, person_name: str):
    cap = cv2.VideoCapture(video_path)
    frame_id = 0
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        # Randomly select a dataset split
        dataset_split = random.choices(["train", "test", "valid"], [0.7, 0.15, 0.15])[0]
        image_filename = f"{person_name}_frame_{frame_id}.jpg"
        label_filename = f"{person_name}_frame_{frame_id}.txt"
        image_path = f"{DATASET_DIR}/{dataset_split}/images/{image_filename}"
        label_path = f"{DATASET_DIR}/{dataset_split}/labels/{label_filename}"

        # Save the frame as an image
        cv2.imwrite(image_path, frame)

        # Run YOLO detection on the frame
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

# def process_video_upload(video_path: str, player_names: str):
    # # Use the number of folders/files in DATASET_DIR as a proxy for person_id
    # i = 0
    # # dict = {}
    # # if player_names:
    # #     with open(f"{DATASET_DIR}/player_names.txt", "a") as f:
    # #         f.write(player_names + "\n")
    # basename = video_path.rsplit(".", 1)[0]  # "emi_a"
    # # Split the basename by underscore
    # name, team = basename.split("_")
    
    # person_id = len(os.listdir(DATASET_DIR))
    # extract_frames(video_path, person_id)
def process_videos(video_folder: str):
    videos = [f for f in os.listdir(video_folder) if f.endswith(('.mp4', '.avi', '.mov'))]
    nc = len(videos)
    names = [os.path.splitext(video)[0] for video in videos]
    data_yaml = {
        'names': names,
        'nc': nc,
        'train': './train',
        'val': './valid',
        'test': './test',
    }
    with open('dataset/data.yaml', 'w') as f:
        yaml.dump(data_yaml, f, default_flow_style=False)
    
    for person_id, video in enumerate(videos):
        video_path = os.path.join(video_folder, video)
        extract_frames(video_path, person_id, names[person_id])
    print("all videos processed and labeled correctly")
    

def train_model_logic():
    # Read the player names to configure class names for training
    # with open(f"{DATASET_DIR}/player_names.txt", "r") as f:
    #     names = [line.strip() for line in f.readlines()]
    
    # data_yaml = {
    #     'train': './train',
    #     'val': './valid',
    #     'test': './test',
    #     'nc': len(names),
    #     'names': names
    # }
    
    # with open(f"{DATASET_DIR}/data.yaml", 'w') as f:
    #     yaml.dump(data_yaml, f, default_flow_style=False)
    
    # Train the model with the generated dataset configuration
    yolo_model.train(data=f"{DATASET_DIR}/data.yaml", epochs=10, imgsz=640, name="person_classifier")
    
    # Export the trained model to CoreML format
    model_coreml = yolo_model.export(format="coreml")
    model_coreml.save("person_classifier.mlmodel")
    
    
    # clear dir
    dir_path = f"{UPLOAD_DIR}"
    for filename in os.listdir(dir_path):
        file_path = os.path.join(dir_path, filename)
        try:
            # Remove file or symbolic link.
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            # Remove directory and its contents.
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
        except Exception as e:
            print(f'Failed to delete {file_path}. Reason: {e}')

def test_model_logic(image_path: str):
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
    return detections


def reset_dataset_dir():
    dir_path = f"{DATASET_DIR}"
    for filename in os.listdir(dir_path):
        file_path = os.path.join(dir_path, filename)
        try:
            # Remove file or symbolic link.
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            # Remove directory and its contents.
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
        except Exception as e:
            print(f'Failed to delete {file_path}. Reason: {e}')
            
            
    subsets = ['train', 'valid', 'test']
    subfolders = ['images', 'labels']

    # Create the directory structure
    for subset in subsets:
        for folder in subfolders:
            folder_path = os.path.join(DATASET_DIR, subset, folder)
            os.makedirs(folder_path, exist_ok=True)
            print(f"Created: {folder_path}")

