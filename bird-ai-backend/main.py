# main.py
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
    "parrot",
    "sparrow",
    "owl"
]

index_to_label = {i: label for i, label in enumerate(labels)}

# =========================
# AUDIO CLEANING
# =========================

def clean_audio(audio, sr):

    # Remove silence
    audio, _ = librosa.effects.trim(audio)

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
# =========================

def make_gradcam_heatmap(img_array, model, last_conv_layer_name):

    img_tensor = tf.convert_to_tensor(
        img_array,
        dtype=tf.float32
    )

    last_conv_layer = model.get_layer(last_conv_layer_name)

    grad_model = tf.keras.models.Model(
        [model.inputs],
        [last_conv_layer.output, model.output]
    )

    with tf.GradientTape() as tape:

        conv_outputs, predictions = grad_model(img_tensor)

        pred_index = tf.argmax(predictions[0])

        class_channel = predictions[:, pred_index]

    grads = tape.gradient(class_channel, conv_outputs)

    pooled_grads = tf.reduce_mean(
        grads,
        axis=(0, 1, 2)
    )

    conv_outputs = conv_outputs[0]

    heatmap = tf.reduce_sum(
        pooled_grads * conv_outputs,
        axis=-1
    )

    heatmap = tf.maximum(heatmap, 0)

    heatmap = heatmap / (tf.reduce_max(heatmap) + 1e-8)

    return heatmap.numpy()


# =========================
# SAVE GRADCAM IMAGE
# =========================

def save_gradcam_image(mel_image, heatmap, output_path):

    heatmap = cv2.resize(
        heatmap,
        (mel_image.shape[1], mel_image.shape[0])
    )

    plt.figure(figsize=(8, 4))

    plt.imshow(mel_image, cmap="gray")

    plt.imshow(heatmap, cmap="jet", alpha=0.4)

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
        "message": "Bird Sound Classification API Running"
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

        input_data = features[np.newaxis, ..., np.newaxis]

        # =========================
        # PREDICTION
        # =========================

        prediction = model.predict(input_data)[0]

        predicted_index = np.argmax(prediction)

        predicted_label = index_to_label[predicted_index]

        confidence = float(prediction[predicted_index])

        probabilities = {
            index_to_label[i]: float(prediction[i])
            for i in range(len(labels))
        }

        # =========================
        # GRAD-CAM
        # =========================

        last_conv_layer_name = "conv2d_2"

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