from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from ultralytics import YOLO
import numpy as np
import uvicorn
import cv2

# Initialize FastAPI app
app = FastAPI()

# Load YOLO model once at startup
model = YOLO("best.pt")

@app.post("/detect/")
async def detect_objects(file: UploadFile = File(...)):
    try:
        # Load the image
        image_bytes = await file.read()
        file_bytes = np.asarray(bytearray(image_bytes), dtype=np.uint8)
        image_np = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)  # BGR
        image_np = cv2.cvtColor(image_np, cv2.COLOR_BGR2RGB)   # Convert to RGB

        # Save original size
        orig_h, orig_w = image_np.shape[:2]

        # Resize the image for YOLO (e.g., 640x640)
        resized_image = cv2.resize(image_np, (640, 640))
        resized_h, resized_w = resized_image.shape[:2]

        # Run YOLO inference
        results = model.predict(resized_image, verbose=False,)[0]

        # Extract bounding boxes and confidence
        detections = []
        for box in results.boxes:
            class_id = int(box.cls)
            x1, y1, x2, y2 = box.xyxy[0].tolist()

            # Scale back to original image size 
            x1 = x1 * (orig_w / resized_w)
            x2 = x2 * (orig_w / resized_w)
            y1 = y1 * (orig_h / resized_h)
            y2 = y2 * (orig_h / resized_h)

            detections.append({
                "class": results.names[class_id],
                "confidence": float(box.conf),
                "bbox": [x1, y1, x2, y2] 
            })

        # Prepare response data
        response_data = {
            "detections": detections
        }

        return JSONResponse({
            "status": "success",
            "detection_data": response_data
        })

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error processing image: {str(e)}")
    
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
#uvicorn main:app --host 0.0.0.0 --port 8080