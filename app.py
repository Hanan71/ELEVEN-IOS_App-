from flask import Flask, request, jsonify
import pickle
import numpy as np

app = Flask(__name__)

# تحميل المودل
model = pickle.load(open("model.pkl", "rb"))

@app.route("/")
def home():
    return "API is running"

@app.route("/predict", methods=["POST"])
def predict():
    data = request.json
    
    age = int(data["age"])
    gender = int(data["gender"])
    screen_time = float(data["screen_time"])

    features = np.array([[age, gender, screen_time]])
    
    prediction = model.predict(features)[0]

    return jsonify({
        "risk": prediction
    })

if __name__ == "__main__":
    app.run()
