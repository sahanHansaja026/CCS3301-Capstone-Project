from fastapi import FastAPI, File, UploadFile
import numpy as np
import tensorflow as tf
import librosa
import cv2
import shutil
import os

app = FastAPI()

# -----------------------------
# 1. LOAD & LOCK MODEL
# -----------------------------
MODEL_PATH = "bird_classifier.h5"

# Load the model structure
model = tf.keras.models.load_model(MODEL_PATH)

# 🔥 THE ULTIMATE WINDOWS/SEQUENTIAL FIX:
# We explicitly build the model with the expected input shape.
# This solves "The layer sequential has never been called" by defining the output tensors.
model.build((None, 128, 128, 1)) 

def prepare_grad_model(model):
    # Find the last Conv2D layer in your CNN stack
    last_conv_layer_name = None
    for layer in reversed(model.layers):
        if isinstance(layer, tf.keras.layers.Conv2D):
            last_conv_layer_name = layer.name
            break
            
    if not last_conv_layer_name:
        raise ValueError("Could not find a Conv2D layer in your model.")

    # Create the specialized Grad-CAM model
    # Because we called model.build() above, model.inputs/outputs are now defined
    grad_model = tf.keras.models.Model(
        inputs=model.inputs,
        outputs=[model.get_layer(last_conv_layer_name).output, model.output]
    )
    
    # Pre-warm the grad model to ensure it's ready in memory
    dummy_input = np.zeros((1, 128, 128, 1), dtype=np.float32)
    _ = grad_model(dummy_input)
    
    return grad_model, last_conv_layer_name

# Initialize these globally so they only run once at startup
try:
    GRAD_MODEL, LAST_CONV_NAME = prepare_grad_model(model)
    print(f"✅ Model Initialized. Target layer: {LAST_CONV_NAME}")
except Exception as e:
    print(f"❌ Initialization failed: {e}")

labels = ["crow", "peacock", "rooster"]

# -----------------------------
# 2. FEATURE EXTRACTION
# -----------------------------
def extract_mel(file_path):
    # Load audio (22.05kHz matches your training)
    audio, sr = librosa.load(file_path, sr=22050)
    
    # Generate Mel Spectrogram
    mel = librosa.feature.melspectrogram(y=audio, sr=sr)
    mel_db = librosa.power_to_db(mel, ref=np.max)
    
    # Resize to exact shape used in training (128x128)
    mel_resized = cv2.resize(mel_db, (128, 128))
    
    # Min-Max Normalization
    mel_min, mel_max = np.min(mel_resized), np.max(mel_resized)
    mel_norm = (mel_resized - mel_min) / (mel_max - mel_min + 1e-8)
    
    return mel_norm.reshape(1, 128, 128, 1)

# -----------------------------
# 3. GRAD-CAM (Explainable AI)
# -----------------------------
def get_grad_cam_heatmap(img_array):
    with tf.GradientTape() as tape:
        last_conv_layer_output, preds = GRAD_MODEL(img_array)
        class_idx = tf.argmax(preds[0])
        loss = preds[:, class_idx]

    # Calculate gradients
    grads = tape.gradient(loss, last_conv_layer_output)
    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))

    # Weight the features
    last_conv_layer_output = last_conv_layer_output[0]
    heatmap = last_conv_layer_output @ pooled_grads[..., tf.newaxis]
    heatmap = tf.squeeze(heatmap)

    # ReLU and Normalize Heatmap
    heatmap = tf.maximum(heatmap, 0) / (tf.math.reduce_max(heatmap) + 1e-8)
    return heatmap.numpy()

# -----------------------------
# 4. API ENDPOINT
# -----------------------------
@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    # Create temp file
    temp_name = f"active_{file.filename}"
    with open(temp_name, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    try:
        # Preprocess audio
        processed_data = extract_mel(temp_name)

        # 1. Standard Prediction
        raw_preds = model.predict(processed_data)
        pred_idx = np.argmax(raw_preds[0])
        confidence = float(raw_preds[0][pred_idx])

        # 2. Generate Explainability Heatmap
        heatmap = get_grad_cam_heatmap(processed_data)

        return {
            "status": "success",
            "prediction": {
                "bird": labels[pred_idx],
                "confidence": round(confidence, 4),
                "label_index": int(pred_idx)
            },
            "interpretation": {
                "heatmap": heatmap.tolist()
            }
        }

    except Exception as e:
        return {"status": "error", "message": f"Server Logic Error: {str(e)}"}
    
    finally:
        # Cleanup file after processing
        if os.path.exists(temp_name):
            os.remove(temp_name)

if __name__ == "__main__":
    import uvicorn
    # Important for Windows: ensure uvicorn runs correctly
    uvicorn.run(app, host="127.0.0.1", port=8000)