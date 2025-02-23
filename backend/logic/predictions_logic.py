from fastapi import FastAPI, UploadFile, File
import cv2
import time
from ultralytics import YOLO
import numpy as np

app = FastAPI()

# Initialize YOLO models (adjust paths as needed)
model = YOLO('../runs/detect/person_classifier/weights/best.pt')
yolo_model = YOLO("best.pt")

# Global in-memory state and stats
state = {
    "hasPossession": None,         # Current possessor's user ID
    "prevHasPossession": None,     # Previous possessor's user ID
    "position": None,              # (x, y) position when possession was lost
    "possession_timestamp": None,  # Time when possession was lost
    "stats": {}                    # Aggregated stats per user (points, steals, turnovers, assists, oreb, dreb, etc.)
}

# --- Helper Functions for Stats ---
def increment_stat(user_id, stat, amount=1):
    if user_id is None:
        return
    if user_id not in state["stats"]:
        state["stats"][user_id] = {}
    state["stats"][user_id][stat] = state["stats"][user_id].get(stat, 0) + amount

def increment_steal(user_id):
    increment_stat(user_id, 'steals')

def increment_turnover(user_id):
    increment_stat(user_id, 'turnovers')

def increment_points(user_id, points):
    increment_stat(user_id, 'points', points)

def record_fga(user_id, three_point=False):
    if three_point:
        increment_stat(user_id, '3FGA')
    else:
        increment_stat(user_id, 'FGA')

def increment_rebound(user_id, rebound_type):
    # rebound_type: "offensive" or "defensive"
    if rebound_type == "offensive":
        increment_stat(user_id, 'oreb')
    else:
        increment_stat(user_id, 'dreb')

def record_assist(user_id):
    increment_stat(user_id, 'assists')

# --- YOLO Processing Helper Functions ---
def process_frame(image):
    """Runs YOLO model on an image and predicts user ID."""
    # Assume image is a BGR image
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = model(image)  # person classifier
    detections = []
    for result in results:
        for box in result.boxes:
            # Get bounding box coordinates and confidence
            x_min, y_min, x_max, y_max = box.xyxy[0].tolist()
            confidence = box.conf[0].item()
            cls = int(box.cls[0].item())
            detections.append({
                "user_id": cls,  # Class ID is used as the user ID
                "bounding_box": [x_min, y_min, x_max, y_max],
                "confidence": confidence
            })
    return detections

def process_video(video_path: str):
    """
    Processes a video frame by frame.
    Detects ball, rim, and person using YOLO.
    Returns a list of detection dictionaries per frame.
    """
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
                user_detections = process_frame(frame)
                frame_detections["user_id"].extend(user_detections)
            elif cls == 0:  # Ball detected
                frame_detections["ball"].append({
                    "bounding_box": [x_min, y_min, x_max, y_max],
                    "confidence": confidence
                })
            elif cls == 2:  # Rim detected
                frame_detections["rim"].append({
                    "bounding_box": [x_min, y_min, x_max, y_max],
                    "confidence": confidence
                })

        frame_results.append(frame_detections)
    cap.release()
    return frame_results

# --- Bounding Box & Event Helpers ---
def is_near(box1, box2):
    """Check if two bounding boxes are close enough (within 30 pixels)."""
    x1_min, y1_min, x1_max, y1_max = box1
    x2_min, y2_min, x2_max, y2_max = box2
    return abs(x1_min - x2_min) < 30 and abs(y1_min - y2_min) < 30

def is_near_goal(ball_box, rim_boxes):
    """Checks if the ball is near any of the rim bounding boxes."""
    for rim in rim_boxes:
        if is_near(ball_box, rim["bounding_box"]):
            return True
    return False

def is_goal(shot_box):
    """Determines if a shot is made (assumes goal is near top of frame)."""
    return shot_box[1] < 50

# --- Possession & Event State Management ---
def update_possession(new_user_id, current_position=None):
    """
    Update possession:
      - Move current possessor to prevHasPossession (with position and timestamp).
      - Set new possessor as hasPossession.
    """
    current_time = time.time()
    if state["hasPossession"] is not None:
        state["prevHasPossession"] = state["hasPossession"]
        state["position"] = current_position
        state["possession_timestamp"] = current_time
    state["hasPossession"] = new_user_id

def auto_null_prev_possession():
    """Automatically clears prevHasPossession if more than 4 seconds have passed."""
    if state["prevHasPossession"] is not None:
        if time.time() - state["possession_timestamp"] > 4:
            state["prevHasPossession"] = None
            state["position"] = None
            state["possession_timestamp"] = None

def determine_possession(frame_detections):
    """
    Determines which user has possession of the ball by checking if the ball is near a user.
    Returns a user_id if found, or None.
    """
    for frame in frame_detections:
        for ball in frame["ball"]:
            ball_box = ball["bounding_box"]
            for user in frame["user_id"]:
                user_box = user["bounding_box"]
                if is_near(ball_box, user_box):
                    return user["user_id"]
    return None

def process_possession_change(new_user_id, current_position=None):
    """
    Process possession change:
      - If a previous possessor exists, decide if this is a pass (same team) or steal (different team).
      - Record an assist for a pass or increment steal/turnover for a steal.
      - Then update the possession state.
    """
    if state["prevHasPossession"] is not None:
        if new_user_id % 2 == state["prevHasPossession"] % 2:
            # Pass scenario (same team): record an assist.
            record_assist(state["prevHasPossession"])
            update_possession(new_user_id, current_position)
        else:
            # Steal scenario (opponent): record steal and turnover.
            increment_steal(new_user_id)
            increment_turnover(state["prevHasPossession"])
            update_possession(new_user_id, current_position)
    else:
        update_possession(new_user_id, current_position)

def process_shot(is_made, shot_type):
    """
    Process a shot event:
      - If made, award points and record the field goal attempt (3-pointer or 2-pointer) based on prevHasPossession.
      - Clear stored position after processing.
    """
    if is_made and state["prevHasPossession"] is not None:
        if shot_type == "3-pointer":
            increment_points(state["prevHasPossession"], 3)
            record_fga(state["prevHasPossession"], three_point=True)
        elif shot_type == "2-pointer":
            increment_points(state["prevHasPossession"], 2)
            record_fga(state["prevHasPossession"], three_point=False)
    state["position"] = None

def process_rebound(new_user_id):
    """
    Process a rebound event:
      - Determine if the rebound is offensive or defensive based on team affiliation
        (comparing new possessor with prevHasPossession).
      - Update the rebound stat accordingly.
      - Update possession to the new possessor.
    """
    if state["prevHasPossession"] is not None:
        if new_user_id % 2 == state["prevHasPossession"] % 2:
            increment_rebound(new_user_id, "defensive")
        else:
            increment_rebound(new_user_id, "offensive")
    update_possession(new_user_id)

# --- Main Game Processing Function ---
def process_game(video_path: str):
    """
    Processes the entire video:
      1. Obtains frame events via process_video.
      2. For each frame event, determines possession and processes any shot or rebound events.
      3. Updates game state and stats.
      4. Returns final state and aggregated stats.
    """
    frames = process_video(video_path)
    for frame_data in frames:
        auto_null_prev_possession()
        # Determine current possessor based on frame detections
        possessor = determine_possession([frame_data])
        current_position = None  # If you have positional info, extract it here.
        if possessor is not None:
            process_possession_change(possessor, current_position)

        # Optionally: If your detections include events, process them.
        # For example, you might detect a shot event by checking if the ball is near the rim.
        if frame_data["ball"] and is_near_goal(frame_data["ball"][0]["bounding_box"], frame_data["rim"]):
            # For simplicity, assume we determine a shot has occurred and check if it was made.
            shot_made = is_goal(frame_data["ball"][0]["bounding_box"])
            # Determine shot type (example logic; you can adjust as needed)
            shot_type = "3-pointer" if frame_data["ball"][0]["bounding_box"][0] < 100 else "2-pointer"
            process_shot(shot_made, shot_type)

        # Optionally, if you detect a rebound (for example, after a shot missed), you can process that:
        # if rebound detected:
        #     rebound_possessor = determine_possession([frame_data])
        #     if rebound_possessor is not None:
        #         process_rebound(rebound_possessor)

    return {"final_state": state, "stats": state["stats"]}
