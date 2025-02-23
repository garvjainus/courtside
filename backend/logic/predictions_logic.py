from fastapi import UploadFile, File
import cv2
import torch
import numpy as np
import coremltools as ct
from ultralytics import YOLO
from PIL import Image

# Do not change these – the models must function exactly as given.
model = YOLO('../runs/detect/person_classifier/weights/best.pt')
yolo_model = YOLO("best.pt")


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

        for box in results[0].boxes:
            cls = int(box.cls.item())
            x_min, y_min, x_max, y_max = box.xyxy[0].tolist()
            confidence = box.conf[0].item()

            if cls == 1:  # Person detected
                user_detections = process_frame(frame)  # Pass frame directly
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


# -------------------------------------------------------------------
# Possession and stat-tracking logic
# -------------------------------------------------------------------

class PossessionTracker:
    # Thresholds (in seconds) – you can adjust these as needed
    POSSESSION_CHANGE_THRESHOLD = 0.5  # Minimum time difference to consider a real change (not just dribbling)
    NO_POSSESSION_TIMEOUT = 2          # Time to wait with no detected possessor before clearing current possession
    PREV_POSSESSION_LIFETIME = 4       # Automatically null prev possession after 4 seconds

    def __init__(self, fps=30):
        self.fps = fps
        self.current_possession = None  # The user ID currently in possession
        self.prev_possession = None     # The last user ID that had possession
        self.stored_position = None     # The (x, y) position when possession was lost
        self.possession_timestamp = 0   # Timestamp (in seconds) when current possession was set
        self.prev_timestamp = 0         # Timestamp when previous possession was recorded
        self.stats = {}  # Dictionary mapping user IDs to their stats
        self.shot_attempted = False  # Flag to indicate if a shot was recently attempted

    def update_stats_for_user(self, user_id):
        if user_id not in self.stats:
            self.stats[user_id] = {
                "points": 0,
                "fga": 0,
                "3fga": 0,
                "steals": 0,
                "turnovers": 0,
                "oreb": 0,
                "dreb": 0
            }

    def process_frame(self, frame_detections, current_time):
        """
        Process one frame’s detections, update possession state and stats.
        Frame detections is a dictionary with keys "ball", "rim", and "user_id".
        """
        # First, try to determine who is in possession based on the ball’s location and nearby person detections.
        possessor = self.determine_possession(frame_detections)
        possessor_id = possessor[0] if possessor is not None else None
        possessor_position = possessor[1] if possessor is not None else None

        # --- Possession state updates ---
        if possessor_id is not None:
            self.update_stats_for_user(possessor_id)
            if self.current_possession is None:
                # No one had possession; assign it to the detected possessor.
                self.current_possession = possessor_id
                self.possession_timestamp = current_time
                self.stored_position = possessor_position
            else:
                if possessor_id != self.current_possession:
                    # Check if the ball truly changed hands (avoid triggering on minor dribbles).
                    if current_time - self.possession_timestamp > self.POSSESSION_CHANGE_THRESHOLD:
                        # Save the previous possessor and update stored position.
                        self.prev_possession = self.current_possession
                        self.prev_timestamp = current_time
                        self.stored_position = possessor_position

                        # Check team alignment to decide whether it’s a pass or a steal.
                        if self.are_teammates(self.prev_possession, possessor_id):
                            # Pass – simply update possession.
                            pass
                        else:
                            # Steal – increment stats accordingly.
                            self.stats[possessor_id]["steals"] += 1
                            self.update_stats_for_user(self.prev_possession)
                            self.stats[self.prev_possession]["turnovers"] += 1

                        self.current_possession = possessor_id
                        self.possession_timestamp = current_time
                    else:
                        # Too short – likely just a dribble. Continue with the current possessor.
                        self.possession_timestamp = current_time
                else:
                    # Same possessor detected – update the timestamp and stored position.
                    self.possession_timestamp = current_time
                    self.stored_position = possessor_position
        else:
            # No possessor detected in this frame.
            if self.current_possession is not None:
                if current_time - self.possession_timestamp > self.NO_POSSESSION_TIMEOUT:
                    self.current_possession = None

            if self.prev_possession is not None and (current_time - self.prev_timestamp > self.PREV_POSSESSION_LIFETIME):
                self.prev_possession = None

        # --- Shot attempt / scoring logic ---
        if frame_detections["rim"]:
            shot_result = self.process_shot(frame_detections)
            if shot_result is not None:
                if shot_result in ["2pt", "3pt"]:
                    # A made shot counts for the previous possessor (if available)
                    if self.prev_possession is not None:
                        self.update_stats_for_user(self.prev_possession)
                        points = 2 if shot_result == "2pt" else 3
                        self.stats[self.prev_possession]["points"] += points
                        self.stats[self.prev_possession]["fga"] += 1
                        if shot_result == "3pt":
                            self.stats[self.prev_possession]["3fga"] += 1
                    # Reset shot state after scoring.
                    self.prev_possession = None
                    self.stored_position = None
                    self.shot_attempted = False
                elif shot_result == "miss":
                    # Record that a shot was attempted but missed.
                    self.shot_attempted = True
                elif shot_result == "rebound":
                    # A rebound is assumed to occur if a person is detected shortly after a missed shot.
                    rebound = self.determine_possession(frame_detections)
                    if rebound is not None:
                        rebound_user_id, _ = rebound
                        self.update_stats_for_user(rebound_user_id)
                        if self.prev_possession is not None:
                            if self.are_teammates(self.prev_possession, rebound_user_id):
                                self.stats[rebound_user_id]["oreb"] += 1
                            else:
                                self.stats[rebound_user_id]["dreb"] += 1
                        self.current_possession = rebound_user_id
                        self.possession_timestamp = current_time
                        self.prev_possession = None
                        self.stored_position = None
                        self.shot_attempted = False

    def determine_possession(self, frame_detections):
        """
        Determines which person is likely in possession of the ball.
        Uses the proximity of the ball’s center to each detected user’s bounding box center.
        Returns a tuple (user_id, center_position) or None if no suitable match.
        """
        if not frame_detections["ball"] or not frame_detections["user_id"]:
            return None
        # Assume the first ball detection is the ball of interest.
        ball_box = frame_detections["ball"][0]["bounding_box"]
        ball_center = ((ball_box[0] + ball_box[2]) / 2, (ball_box[1] + ball_box[3]) / 2)
        min_dist = float('inf')
        possessor = None
        for detection in frame_detections["user_id"]:
            user_box = detection["bounding_box"]
            user_center = ((user_box[0] + user_box[2]) / 2, (user_box[1] + user_box[3]) / 2)
            dist = self.distance(ball_center, user_center)
            if dist < min_dist:
                min_dist = dist
                possessor = (detection["user_id"], user_center)
        # Use an arbitrary threshold to ensure the ball is “close enough” to a player.
        if min_dist < 100:
            return possessor
        return None

    def process_shot(self, frame_detections):
        """
        Processes a shot event. For simplicity, if the ball’s center falls within a rim bounding box,
        the shot is considered made. The shot type (2pt vs 3pt) is determined based on the stored possession
        position relative to a fixed basket position.
        Returns:
          - "2pt" or "3pt" if the shot is made,
          - "miss" if the shot is attempted but missed,
          - "rebound" if the ball is recovered after a missed shot.
          - None if no shot event is determined.
        """
        ball_detected = frame_detections["ball"]
        rim_detected = frame_detections["rim"]
        if not ball_detected or not rim_detected:
            return None

        ball_box = ball_detected[0]["bounding_box"]
        ball_center = ((ball_box[0] + ball_box[2]) / 2, (ball_box[1] + ball_box[3]) / 2)

        for rim in rim_detected:
            rim_box = rim["bounding_box"]
            # Check if the ball center is inside the rim’s bounding box.
            if (rim_box[0] <= ball_center[0] <= rim_box[2]) and (rim_box[1] <= ball_center[1] <= rim_box[3]):
                # Determine shot type based on distance from stored position to a fixed basket position.
                if self.stored_position is not None:
                    # Assume a fixed basket location; adjust these placeholder values as needed.
                    basket_position = (640, 100)
                    dist_to_basket = self.distance(self.stored_position, basket_position)
                    # If the distance exceeds an arbitrary threshold, call it a 3-pointer.
                    if dist_to_basket > 200:
                        return "3pt"
                    else:
                        return "2pt"
        # If the ball is near the rim but not clearly inside, assume a miss.
        return "miss"

    def distance(self, p1, p2):
        """Calculates Euclidean distance between two points."""
        return ((p1[0] - p2[0])**2 + (p1[1] - p2[1])**2)**0.5

    def are_teammates(self, user1, user2):
        """Assumes even user IDs are one team and odd ones are the other."""
        return (user1 % 2) == (user2 % 2)


def process_game(video_path: str):
    """
    Processes a video file from start to finish, using the detection outputs
    (from process_video) to update game stats.
    
    Returns a stats dictionary mapping user IDs to their stats.
    """
    frame_results = process_video(video_path)
    tracker = PossessionTracker(fps=30)
    frame_index = 0
    for frame_detections in frame_results:
        current_time = frame_index / tracker.fps
        tracker.process_frame(frame_detections, current_time)
        frame_index += 1
    return tracker.stats


# Example usage:
# stats = process_game("path_to_video.mp4")
# print(stats)
