from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any

# --- Data Structures ---

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
    details: Dict[str, Any]  # e.g., {"from": playerA, "to": playerB, ...}

@dataclass
class PlayerStats:
    player_id: int
    points: int = 0
    steals: int = 0
    turnovers: int = 0
    assists: int = 0
    offensive_rebounds: int = 0
    defensive_rebounds: int = 0

# Our ongoing stats structure: dictionary mapping player_id to PlayerStats.
player_stats: Dict[int, PlayerStats] = {}

def get_or_create_player_stats(player_id: int) -> PlayerStats:
    if player_id not in player_stats:
        player_stats[player_id] = PlayerStats(player_id=player_id)
    return player_stats[player_id]

# --- Helper Functions for Detection and State Extraction ---

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
    Given a frame (as a parsed JSON dictionary), extract a simple state.
    Expects keys: "ball", "rim", and "user_id".
    """
    detections = FrameDetections(
        balls=[Detection("ball", BoundingBox(*ball["bounding_box"]), ball["confidence"])
               for ball in frame.get("ball", [])],
        rims=[Detection("rim", BoundingBox(*rim["bounding_box"]), rim["confidence"])
              for rim in frame.get("rim", [])],
        players=[Detection("player", BoundingBox(*player["bounding_box"]), player["confidence"], player.get("user_id"))
                 for player in frame.get("user_id", [])]
    )
    possession = determine_possession(detections)
    shot = bool(detect_shots(detections))
    return {"possession": possession, "shot": shot}

def aggregate_window_state(window_states: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Aggregate states from a sliding window of frames.
    Here, we simply take the last frame’s possession and OR any shot detection.
    """
    aggregated_possession = window_states[-1]["possession"]
    aggregated_shot = any(state["shot"] for state in window_states)
    return {"possession": aggregated_possession, "shot": aggregated_shot}

def determine_event_change(prev_state: Dict[str, Any],
                           curr_state: Dict[str, Any],
                           frame_index: int,
                           frame_rate: float = 30.0) -> Optional[GameEvent]:
    """
    Compare two aggregated states and determine if an event is triggered.
    """
    timestamp = frame_index / frame_rate
    # Check for shot: prioritize if the shot was not seen before.
    if not prev_state["shot"] and curr_state["shot"]:
        return GameEvent(
            event_type="shot",
            time=timestamp,
            details={"possession": curr_state["possession"], "result": "Undecided"}  # Extend as needed.
        )
    # Possession change might indicate a pass, turnover, or steal.
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
    # Dribbling: if possession remains constant over the window.
    if curr_state["possession"] is not None and prev_state["possession"] == curr_state["possession"]:
        return GameEvent(
            event_type="dribble",
            time=timestamp,
            details={"player": curr_state["possession"]}
        )
    return None

# --- Stats Update Function ---

def update_player_stats(event: GameEvent):
    """
    Update the player's stats based on the event triggered.
    """
    # For a shot event, if the shot is later confirmed as "Made", add points.
    if event.event_type == "shot":
        shooter = event.details.get("possession")
        if shooter is not None:
            ps = get_or_create_player_stats(shooter)
            # Assume a made shot is worth 2 points; extend logic as needed.
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
    # Offensive and defensive rebounds can be added when that event is detected.
    # For example:
    # elif event.event_type == "offensive_rebound":
    #     ps = get_or_create_player_stats(event.details.get("player"))
    #     ps.offensive_rebounds += 1
    # elif event.event_type == "defensive_rebound":
    #     ps = get_or_create_player_stats(event.details.get("player"))
    #     ps.defensive_rebounds += 1

# --- Sliding Window Processing Algorithm ---

def process_frames_with_sliding_window(frames: List[dict],
                                       window_size: int = 3,
                                       frame_rate: float = 30.0) -> List[GameEvent]:
    """
    Process a list of frames (as parsed JSON) using a sliding window.
    When an aggregated state change is detected, trigger an event and update player stats.
    Returns a list of GameEvent objects.
    """
    events: List[GameEvent] = []
    total_frames = len(frames)
    if total_frames < window_size:
        return events

    # Initialize the sliding window with the first window_size frames.
    window_states = [get_frame_state(frame) for frame in frames[:window_size]]
    prev_agg_state = aggregate_window_state(window_states)

    # Slide the window over frames one by one.
    for i in range(window_size, total_frames):
        window_states.pop(0)
        window_states.append(get_frame_state(frames[i]))
        curr_agg_state = aggregate_window_state(window_states)
        
        if curr_agg_state != prev_agg_state:
            event = determine_event_change(prev_agg_state, curr_agg_state, frame_index=i, frame_rate=frame_rate)
            if event is not None:
                events.append(event)
                # Update the ongoing stats for players based on this event.
                update_player_stats(event)
        prev_agg_state = curr_agg_state

    return events