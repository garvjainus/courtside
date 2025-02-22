import torch
import coremltools as ct
from ultralytics import YOLO

model = YOLO('/Users/mites/Documents/courtside/backend/runs/detect/person_classifier/weights/best.pt')

model.export(format='coreml',nms=True)

coreml_model = ct.models.MLModel('/Users/mites/Documents/courtside/backend/runs/detect/person_classifier/weights/best.mlpackage/Data/com.apple.CoreML/model.mlmodel')
print(coreml_model.input_description)
input_example = torch.randn(1, 3, 640, 640)
coreml_model.input_description['image'] = 'Input image for YOLOv8'
coreml_model.save('person_classifier.mlmodel')
print("Model saved as person_classifier.mlmodel")