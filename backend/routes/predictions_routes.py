from fastapi import APIRouter, UploadFile, File
from logic.predictions_logic import process_video, determine_possession, detect_passes, detect_shots, detect_shot_results

predictions_routes = APIRouter()

@predictions_routes.post("/predict_video/")
async def predict_video(file: UploadFile = File(...)):
    """Receives a video, runs YOLO prediction, and returns detections for ball, rim, and user ID, including actions."""
    video_path = f"uploads/{file.filename}"
    with open(video_path, "wb") as f:
        f.write(await file.read())
    
    frame_detections = process_video(video_path)
    possession = determine_possession(frame_detections)
    passes = detect_passes(frame_detections)
    shots = detect_shots(frame_detections)
    shot_results = detect_shot_results(frame_detections)
    
    return {
        "detections": frame_detections,
        "possession": possession,
        "passes": passes,
        "shots": shots,
        "shot_results": shot_results
    }
