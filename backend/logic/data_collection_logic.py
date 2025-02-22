import os
import shutil
import cv2
from ultralytics import YOLO
import numpy as np

# Directory to store trained identities
TRAINED_PERSON_DIR = "trained_persons"
TRAINING_DATA_DIR = "person_training_data"
os.makedirs(TRAINED_PERSON_DIR, exist_ok=True)
os.makedirs(TRAINING_DATA_DIR, exist_ok=True)

def iou(box1, box2):
    """Calculate Intersection over Union (IoU) of two bounding boxes."""
    x1, y1, x2, y2 = box1
    xx1, yy1, xx2, yy2 = box2

    # Calculate the intersection area
    inter_area = max(0, min(x2, xx2) - max(x1, xx1)) * max(0, min(y2, yy2) - max(y1, yy1))

    # Calculate the union area
    box1_area = (x2 - x1) * (y2 - y1)
    box2_area = (xx2 - xx1) * (yy2 - yy1)

    return inter_area / float(box1_area + box2_area - inter_area)

def prepare_person_data_for_training():
    """Prepares dataset from the frames in trained_persons without using a YAML file."""
    
    # Iterate over each person directory in the trained persons folder
    for person_id_folder in os.listdir(TRAINED_PERSON_DIR):
        person_folder_path = os.path.join(TRAINED_PERSON_DIR, person_id_folder)
        
        if os.path.isdir(person_folder_path):
            person_images = [f for f in os.listdir(person_folder_path) if f.endswith('.jpg')]
            
            if not person_images:
                print(f"No images found for {person_id_folder}. Skipping.")
                continue
            
            # Create a folder for each person in the YOLOv8 dataset directory
            person_training_folder = os.path.join(TRAINING_DATA_DIR, person_id_folder)
            os.makedirs(person_training_folder, exist_ok=True)
            
            # Create a folder for images and labels
            images_folder_train = os.path.join(person_training_folder, "images", "train")
            labels_folder_train = os.path.join(person_training_folder, "labels", "train")
            os.makedirs(images_folder_train, exist_ok=True)
            os.makedirs(labels_folder_train, exist_ok=True)
            
            # Move the person's images into the "images/train" folder
            for image_file in person_images:
                image_path = os.path.join(person_folder_path, image_file)
                new_image_path = os.path.join(images_folder_train, image_file)
                shutil.copy(image_path, new_image_path)
                
                # Create corresponding label files in YOLO format (just a placeholder for now)
                label_file = image_file.replace('.jpg', '.txt')
                label_path = os.path.join(labels_folder_train, label_file)
                
                with open(label_path, 'w') as f:
                    # Example: For each frame, the label would include the class (0 for person) and the normalized bbox coordinates
                    # For simplicity, assuming all boxes are [0, 0, 1, 1] (i.e., the entire image).
                    # In a real scenario, you'd need to extract the correct bbox info.
                    f.write("0 0 0 1 1\n")
            
            # Create a validation set if desired (using a small subset of training data for validation)
            images_folder_val = os.path.join(person_training_folder, "images", "val")
            labels_folder_val = os.path.join(person_training_folder, "labels", "val")
            os.makedirs(images_folder_val, exist_ok=True)
            os.makedirs(labels_folder_val, exist_ok=True)

            # Copy a few images from the training set to the validation set
            val_images = person_images[:int(len(person_images) * 0.2)]  # 20% for validation
            for image_file in val_images:
                image_path = os.path.join(images_folder_train, image_file)
                new_image_path = os.path.join(images_folder_val, image_file)
                shutil.copy(image_path, new_image_path)
                
                # Copy corresponding label file
                label_file = image_file.replace('.jpg', '.txt')
                label_path = os.path.join(labels_folder_train, label_file)
                new_label_path = os.path.join(labels_folder_val, label_file)
                shutil.copy(label_path, new_label_path)
                
            print(f"Prepared training data for {person_id_folder}.")
        
def create_data_yaml():
    """Create the data.yaml file for YOLOv8."""
    data_yaml = """
    train: "/path/to/your/images/train"
    val: "/path/to/your/images/val"
    nc: 1
    names: ['person']
    """
    
    # Save the YAML to a file
    with open("data.yaml", "w") as f:
        f.write(data_yaml)

def train_yolov8_for_person():
    """Train YOLOv8 model for person detection."""
    
    # Create the YAML file before training
    create_data_yaml()
    
    # Load YOLOv8 model
    model = YOLO("yolov8n.pt")  # or "yolov8x.pt" for a more complex model
    
    # Train the model using the data.yaml
    model.train(
        data="data.yaml",  # Path to the data.yaml file
        imgsz=640,  # Set the image size for training
        batch=16,   # Set the batch size
        epochs=10,  # Number of epochs
        project="person_training",  # Set the project name
        name="person_detection_model",  # Set the model name
        exist_ok=True,  # Overwrite previous runs
    )

def train_person_tracking(video_path: str, model_path: str = "mode/yolov8n.pt"):
    """Detects persons in a video, extracts frames, and matches persons using IoU for tracking."""
    
    # Load YOLOv8 model
    model = YOLO(model_path)
    cap = cv2.VideoCapture(video_path)
    frame_id = 0
    person_frames = []  # List to store frames with detected persons
    tracked_boxes = []  # List of boxes for each detected person

    # List to keep track of the identities of detected persons
    person_id_map = {}

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        results = model(frame)  # Run YOLO inference
        detections = []
        
        # Process detections
        for result in results:
            for box in result.boxes:  # Iterate over detections
                if int(box.cls) == 0:  # Class 0 corresponds to 'person'
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    conf = box.conf[0].item()
                    detections.append([x1, y1, x2, y2, conf])

        # Match detections from the current frame with tracked boxes from previous frames
        new_tracked_boxes = []
        for det in detections:
            x1, y1, x2, y2, conf = det
            matched = False
            for track_id, prev_box in tracked_boxes:
                if iou([x1, y1, x2, y2], prev_box) > 0.5:  # IoU threshold to match
                    new_tracked_boxes.append((track_id, [x1, y1, x2, y2]))
                    matched = True
                    break
            if not matched:
                # If no match found, create a new tracking ID
                new_track_id = len(person_id_map) + 1
                person_id_map[new_track_id] = (x1, y1, x2, y2)
                new_tracked_boxes.append((new_track_id, [x1, y1, x2, y2]))
                
            # Save the frame whenever a person is detected or tracked
            person_crop = frame[y1:y2, x1:x2]
            person_frames.append(person_crop)

        tracked_boxes = new_tracked_boxes

        # Display the frame with tracked people
        for track_id, bbox in tracked_boxes:
            x1, y1, x2, y2 = bbox
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(frame, f"ID: {track_id}", (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5)
        cv2.imshow("Tracking", frame)
        
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()