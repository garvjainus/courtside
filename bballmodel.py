import os
from ultralytics import YOLO
import yaml

model = YOLO("yolov8n.pt")
model.train(data='datasets/basketball-cv/data.yaml', epochs=8, imgsz=640, batch=16, name="basketball-cv", freeze=0)

model.export(format="onnx")
model.export(format="tflite")
model.export(format="coreml")
