import os

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import numpy as np
import librosa
import tensorflow as tf
import cv2
import matplotlib.pyplot as plt
from tensorflow.keras.models import load_model


# =========================
# FASTAPI INIT
# =========================

app = FastAPI(title="Bird Sound Classification API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =========================
# LOAD MODEL
# =========================

MODEL_PATH = "bird_classifier.keras"

model = load_model(MODEL_PATH)


# =========================
# LABELS
# IMPORTANT:
# Use SAME ORDER as training
# =========================

labels = [
   "crow",
    "greenbilled coucal",
    "peacock",
    "rooster"
]

index_to_label = {i: label for i, label in enumerate(labels)}


# =========================
# GET LAST CONV LAYER NAME
# (Auto-detect from model)
# =========================

def get_last_conv_layer_name(model):
    for layer in reversed(model.layers):
        if isinstance(layer, tf.keras.layers.Conv2D):
            return layer.name
    raise ValueError(
        "No Conv2D layer found in model. "
        "Cannot perform Grad-CAM. "
        "Available layers: " + str([l.name for l in model.layers])
    )

last_conv_layer_name = get_last_conv_layer_name(model)
print(f"[INFO] Using last Conv2D layer for Grad-CAM: '{last_conv_layer_name}'")
print(f"[INFO] All model layers: {[l.name for l in model.layers]}")


# =========================
# AUDIO CLEANING
# =========================

def clean_audio(audio, sr):

    # Remove silence
    audio, _ = librosa.effects.trim(audio)

    # Guard: empty audio after trimming
    if len(audio) == 0:
        raise ValueError(
            "Audio file is empty or entirely silence after trimming. "
            "Please provide a file with audible bird sounds."
        )

    # Normalize
    audio = librosa.util.normalize(audio)

    return audio


# =========================
# FEATURE EXTRACTION
# =========================

def extract_features(audio, sr, max_len=128):

    mel = librosa.feature.melspectrogram(
        y=audio,
        sr=sr
    )

    mel_db = librosa.power_to_db(mel, ref=np.max)

    # Padding / Trimming
    if mel_db.shape[1] < max_len:
        pad_width = max_len - mel_db.shape[1]
        mel_db = np.pad(
            mel_db,
            ((0, 0), (0, pad_width))
        )
    else:
        mel_db = mel_db[:, :max_len]

    return mel_db


# =========================
# GRAD-CAM
#
# WHY TWO MODELS:
# A single grad_model with two outputs (conv + predictions)
# runs both in one forward pass. Calling tape.watch(conv_outputs)
# AFTER they are computed does nothing — the tape has no record
# of operations that happened before watch() was called.
#
# Solution: split into two models.
#   conv_model : input -> conv layer output  (run OUTSIDE tape)
#   classifier : conv output -> predictions  (run INSIDE tape, layer-by-layer)
#
# We watch conv_outputs between the two runs, so
# tape.gradient(class_score, conv_outputs) works correctly.
# =========================

def make_gradcam_heatmap(img_array, model, last_conv_layer_name):

    # Model 1: input -> last conv layer output
    conv_model = tf.keras.models.Model(
        inputs=model.inputs,
        outputs=model.get_layer(last_conv_layer_name).output
    )

    # Index of the conv layer in the full model
    conv_layer_index = next(
        i for i, layer in enumerate(model.layers)
        if layer.name == last_conv_layer_name
    )

    # Layers that come AFTER the conv layer
    classifier_layers = model.layers[conv_layer_index + 1:]

    # Cast input to float32
    img_tensor = tf.cast(img_array, dtype=tf.float32)

    # Step 1 (OUTSIDE tape): run up to conv layer — no gradient needed here
    conv_outputs = conv_model(img_tensor, training=False)

    with tf.GradientTape() as tape:

        # Step 2: watch conv_outputs BEFORE any further computation
        tape.watch(conv_outputs)

        # Step 3: run classifier layers on conv_outputs (INSIDE tape)
        x = conv_outputs
        for layer in classifier_layers:
            x = layer(x, training=False)
        predictions = x

        # Step 4: score for the predicted class
        pred_index = tf.argmax(predictions[0])
        class_channel = predictions[:, pred_index]

    # Gradients of class score w.r.t. conv layer activations
    grads = tape.gradient(class_channel, conv_outputs)

    if grads is None:
        raise ValueError(
            f"Grad-CAM gradient is still None after two-model split "
            f"for layer '{last_conv_layer_name}'. "
            f"Model layers: {[l.name for l in model.layers]}"
        )

    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))

    conv_outputs = conv_outputs[0]

    heatmap = tf.reduce_sum(pooled_grads * conv_outputs, axis=-1)

    heatmap = tf.maximum(heatmap, 0)

    heatmap = heatmap / (tf.reduce_max(heatmap) + 1e-8)

    return heatmap.numpy()


# =========================
# SAVE GRADCAM IMAGE
# =========================

def save_gradcam_image(mel_image, heatmap, output_path):

    heatmap_resized = cv2.resize(
        heatmap,
        (mel_image.shape[1], mel_image.shape[0])
    )

    plt.figure(figsize=(8, 4))
    plt.imshow(mel_image, cmap="gray", aspect="auto")
    plt.imshow(heatmap_resized, cmap="jet", alpha=0.4, aspect="auto")
    plt.axis("off")
    plt.title("Grad-CAM Explainable AI")
    plt.savefig(output_path, bbox_inches="tight")
    plt.close()


# =========================
# ROOT ROUTE
# =========================

@app.get("/")
def home():
    return {
        "message": "Bird Sound Classification API Running",
        "grad_cam_layer": last_conv_layer_name,
        "labels": labels
    }


# =========================
# PREDICT ROUTE
# =========================

@app.post("/predict")
async def predict(file: UploadFile = File(...)):

    temp_path = f"temp_{file.filename}"

    # Save uploaded file
    with open(temp_path, "wb") as f:
        f.write(await file.read())

    try:

        # =========================
        # LOAD AUDIO
        # =========================

        audio, sr = librosa.load(
            temp_path,
            sr=22050
        )

        audio = clean_audio(audio, sr)

        # =========================
        # FEATURE EXTRACTION
        # =========================

        features = extract_features(audio, sr)

        # Ensure float32 from the start
        input_data = features[np.newaxis, ..., np.newaxis].astype(np.float32)

        # =========================
        # PREDICTION
        # =========================

        prediction = model.predict(input_data)[0]

        predicted_index = int(np.argmax(prediction))

        predicted_label = index_to_label[predicted_index]

        confidence = float(prediction[predicted_index])

        probabilities = {
            index_to_label[i]: round(float(prediction[i]), 4)
            for i in range(len(labels))
        }

        # =========================
        # GRAD-CAM
        # =========================

        heatmap = make_gradcam_heatmap(
            input_data,
            model,
            last_conv_layer_name
        )

        gradcam_path = f"gradcam_{file.filename}.png"

        save_gradcam_image(
            features,
            heatmap,
            gradcam_path
        )

        # =========================
        # RESPONSE
        # =========================

        return {
            "predicted_bird": predicted_label,
            "confidence": round(confidence, 4),
            "all_probabilities": probabilities,
            "explainable_ai": {
                "gradcam_image": gradcam_path,
                "grad_cam_layer_used": last_conv_layer_name,
                "description":
                    "Red/yellow areas show important sound regions used by AI prediction."
            }
        }

    except Exception as e:
        return {
            "error": str(e)
        }

    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


# =========================
# RUN SERVER
# =========================

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )