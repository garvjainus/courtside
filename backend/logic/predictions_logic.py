import cv2
import json
from fastapi import UploadFile, File
import torch
import numpy as np
import coremltools as ct
from ultralytics import YOLO
from PIL import Image
from dataclasses import dataclass, field, asdict
from typing import List, Optional, Dict, Any

# --- YOLO Detection Setup ---

# Load two YOLO models: one for person classification and one for general object detection.
model = YOLO('../runs/detect/person_classifier/weights/best.pt')
yolo_model = YOLO("best.pt")


def process_frame(image: any):
    """Runs YOLO model on an image and predicts user ID."""
    # Convert image from BGR to RGB.
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    # Run inference using the person classifier model.
    results = model(image)
    detections = []
    for result in results:
        for box in result.boxes:
            # Extract bounding box coordinates, confidence, and use class id as user_id.
            x_min, y_min, x_max, y_max = box.xyxy[0].tolist()
            confidence = box.conf[0].item()
            cls = int(box.cls[0].item())
            detections.append({
                "user_id": cls,  # Using class ID as the unique user ID.
                "bounding_box": [x_min, y_min, x_max, y_max],
                "confidence": confidence
            })
    return detections


def process_video(video_path: str):
    """
    Processes video, detects ball, rim, and person, and predicts user ID if a person is detected.
    Returns a list of frame detection dictionaries.
    Each dictionary has keys: "ball", "rim", and "user_id".
    """
    cap = cv2.VideoCapture(video_path)
    frame_results = []
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        
        # Run general detection to find all objects.
        results = yolo_model(frame)
        frame_detections = {"ball": [], "rim": [], "user_id": []}
        
        for box in results[0].boxes:
            cls = int(box.cls.item())
            x_min, y_min, x_max, y_max = box.xyxy[0].tolist()
            confidence = box.conf[0].item()
            
            if cls == 1:  # Person detected
                user_detections = process_frame(frame)  # Get user details.
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

# --- Event Generation & Stats Update Code ---

@dataclass
class BoundingBox:
    x_min: float
    y_min: float
    x_max: float
    y_max: float

@dataclass
class Detection:
    object_type: str         # "ball", "rim", "player"
    bounding_box: BoundingBox
    confidence: float
    user_id: Optional[int] = None  # Only for player detections

@dataclass
class FrameDetections:
    balls: List[Detection] = field(default_factory=list)
    rims: List[Detection] = field(default_factory=list)
    players: List[Detection] = field(default_factory=list)

@dataclass
class GameEvent:
    event_type: str          # "pass", "shot", "turnover", "steal", "dribble"
    time: float              # Timestamp (in seconds)
    details: Dict[str, Any]  # Additional event details

@dataclass
class PlayerStats:
    player_id: int
    points: int = 0
    steals: int = 0
    turnovers: int = 0
    assists: int = 0
    offensive_rebounds: int = 0
    defensive_rebounds: int = 0

# Global dictionary to hold ongoing player stats.
player_stats: Dict[int, PlayerStats] = {}

def get_or_create_player_stats(player_id: int) -> PlayerStats:
    if player_id not in player_stats:
        player_stats[player_id] = PlayerStats(player_id=player_id)
    return player_stats[player_id]

def is_near(box1, box2):
    """Check if two bounding boxes are near using a center-distance method."""
    x1_min, y1_min, x1_max, y1_max = box1
    x2_min, y2_min, x2_max, y2_max = box2
    center1 = ((x1_min + x1_max) / 2, (y1_min + y1_max) / 2)
    center2 = ((x2_min + x2_max) / 2, (y2_min + y2_max) / 2)
    distance = ((center1[0] - center2[0])**2 + (center1[1] - center2[1])**2) ** 0.5
    return distance < 50

def is_near_goal(ball_box, rim_detections: List[Detection]):
    """Checks if the ball is near any detected rim."""
    for rim in rim_detections:
        rim_box = [rim.bounding_box.x_min, rim.bounding_box.y_min,
                   rim.bounding_box.x_max, rim.bounding_box.y_max]
        if is_near(ball_box, rim_box):
            return True
    return False

def is_goal(shot_box):
    """Determines if a shot is a goal.
       For simplicity, assume a goal if the ball's top coordinate is near the top of the frame."""
    return shot_box[1] < 50

def determine_possession(frame: FrameDetections) -> Optional[int]:
    """Determines which player (user_id) has possession of the ball."""
    for ball in frame.balls:
        ball_box = [ball.bounding_box.x_min, ball.bounding_box.y_min,
                    ball.bounding_box.x_max, ball.bounding_box.y_max]
        for player in frame.players:
            player_box = [player.bounding_box.x_min, player.bounding_box.y_min,
                          player.bounding_box.x_max, player.bounding_box.y_max]
            if is_near(ball_box, player_box):
                return player.user_id
    return None

def detect_shots(frame: FrameDetections) -> List[BoundingBox]:
    """Detect shot attempts based on ball proximity to the rim."""
    shot_boxes = []
    for ball in frame.balls:
        ball_box = [ball.bounding_box.x_min, ball.bounding_box.y_min,
                    ball.bounding_box.x_max, ball.bounding_box.y_max]
        if is_near_goal(ball_box, frame.rims):
            shot_boxes.append(BoundingBox(*ball_box))
    return shot_boxes

def detect_shot_results(frame: FrameDetections) -> List[str]:
    """Determines if each shot attempt is made or missed."""
    shot_results = []
    for shot in detect_shots(frame):
        shot_box = [shot.x_min, shot.y_min, shot.x_max, shot.y_max]
        shot_results.append("Made" if is_goal(shot_box) else "Missed")
    return shot_results

def get_frame_state(frame: dict) -> Dict[str, Any]:
    """
    Converts a detection dictionary (from process_video) into a simplified state.
    Expected keys: "ball", "rim", and "user_id".
    """
    # Convert ball detections to Detection objects.
    balls = [Detection("ball", BoundingBox(*ball["bounding_box"]), ball["confidence"])
             for ball in frame.get("ball", [])]
    # Convert rim detections.
    rims = [Detection("rim", BoundingBox(*rim["bounding_box"]), rim["confidence"])
            for rim in frame.get("rim", [])]
    # Convert player detections.
    players = [Detection("player", BoundingBox(*player["bounding_box"]), player["confidence"], player.get("user_id"))
               for player in frame.get("user_id", [])]
    detections = FrameDetections(balls=balls, rims=rims, players=players)
    
    possession = determine_possession(detections)
    shot = bool(detect_shots(detections))
    return {"possession": possession, "shot": shot}

def aggregate_window_state(window_states: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Aggregates states from a sliding window of frames.
    Uses the last frame's possession and OR's shot detections across the window.
    """
    aggregated_possession = window_states[-1]["possession"]
    aggregated_shot = any(state["shot"] for state in window_states)
    return {"possession": aggregated_possession, "shot": aggregated_shot}

def determine_event_change(prev_state: Dict[str, Any],
                           curr_state: Dict[str, Any],
                           frame_index: int,
                           frame_rate: float = 30.0) -> Optional[GameEvent]:
    """
    Compares two aggregated states and determines if a game event should be triggered.
    """
    timestamp = frame_index / frame_rate
    if not prev_state["shot"] and curr_state["shot"]:
        return GameEvent(
            event_type="shot",
            time=timestamp,
            details={"possession": curr_state["possession"], "result": "Undecided"}
        )
    if prev_state["possession"] != curr_state["possession"]:
        if prev_state["possession"] is not None and curr_state["possession"] is not None:
            return GameEvent(
                event_type="pass",
                time=timestamp,
                details={"from": prev_state["possession"], "to": curr_state["possession"]}
            )
        elif prev_state["possession"] is not None and curr_state["possession"] is None:
            return GameEvent(
                event_type="turnover",
                time=timestamp,
                details={"lost_by": prev_state["possession"]}
            )
        elif prev_state["possession"] is None and curr_state["possession"] is not None:
            return GameEvent(
                event_type="steal",
                time=timestamp,
                details={"gained_by": curr_state["possession"]}
            )
    if curr_state["possession"] is not None and prev_state["possession"] == curr_state["possession"]:
        return GameEvent(
            event_type="dribble",
            time=timestamp,
            details={"player": curr_state["possession"]}
        )
    return None

def update_player_stats(event: GameEvent):
    """
    Updates player statistics based on the detected event.
    """
    if event.event_type == "shot":
        shooter = event.details.get("possession")
        if shooter is not None:
            ps = get_or_create_player_stats(shooter)
            if event.details.get("result") == "Made":
                ps.points += 2
    elif event.event_type == "pass":
        passer = event.details.get("from")
        if passer is not None:
            ps = get_or_create_player_stats(passer)
            ps.assists += 1
    elif event.event_type == "turnover":
        player = event.details.get("lost_by")
        if player is not None:
            ps = get_or_create_player_stats(player)
            ps.turnovers += 1
    elif event.event_type == "steal":
        player = event.details.get("gained_by")
        if player is not None:
            ps = get_or_create_player_stats(player)
            ps.steals += 1

def process_frames_with_sliding_window(frames: List[dict],
                                       window_size: int = 10,
                                       frame_rate: float = 30.0) -> List[GameEvent]:
    """
    Processes a list of detection dictionaries (one per frame) using a sliding window.
    Generates game events when state changes occur and updates player stats.
    """
    events: List[GameEvent] = []
    total_frames = len(frames)
    if total_frames < window_size:
        return events

    window_states = [get_frame_state(frame) for frame in frames[:window_size]]
    prev_agg_state = aggregate_window_state(window_states)
    
    for i in range(window_size, total_frames):
        window_states.pop(0)
        window_states.append(get_frame_state(frames[i]))
        curr_agg_state = aggregate_window_state(window_states)
       
        if curr_agg_state != prev_agg_state:
            event = determine_event_change(prev_agg_state, curr_agg_state, frame_index=i, frame_rate=frame_rate)
            if event is not None:
                events.append(event)
                update_player_stats(event)
        prev_agg_state = curr_agg_state

    return events

def process_video_and_generate_events(video_path: str,
                                      window_size: int = 10,
                                      frame_rate: float = 30.0,
                                      output_json_path: str = "../game_results.json"):
    """
    Unified function that:
      1. Processes the video using YOLO to get detection data.
      2. Uses a sliding window algorithm to generate game events.
      3. Updates player statistics.
      4. Stores the resulting events and stats as JSON.
    """
    # Step 1: Run detection on the video.
    frames_json = process_video(video_path)
    
    # Step 2: Process frames with a sliding window to generate events.
    events = process_frames_with_sliding_window(frames_json, window_size, frame_rate)
    
    # Serialize events and player stats.
    events_serialized = [asdict(event) for event in events]
    player_stats_serialized = {pid: asdict(stats) for pid, stats in player_stats.items()}
    
    output = {
        "game_events": events_serialized,
        "player_stats": player_stats_serialized
    }
    
    # Step 3: Write the JSON output.
    with open(output_json_path, "w") as f:
        json.dump(output, f, indent=4)
    
    print(f"Processed video and stored output to {output_json_path}")
