from flask import Flask, request, jsonify
import pickle
import numpy as np

app = Flask(__name__)

# تحميل المودل
model = pickle.load(open("model.pkl", "rb"))

# تحويل الرقم إلى مستوى خطر
def map_prediction(pred):
    return ["low", "medium", "high"][pred]

@app.route("/")
def home():
    return "API is running"

@app.route("/predict", methods=["POST"])
def predict():
    data = request.json

    # بيانات المودل
    age = int(data["age"])
    gender = int(data["gender"])  # 0 أو 1
    screen_time = float(data["screen_time"])

    features = np.array([[age, gender, screen_time]])

    # prediction
    prediction = model.predict(features)[0]
    risk = map_prediction(prediction)

    # 👇 تجهيز البيانات للـ AI (بدون اسم)
    response_data = {
        "risk": risk,
        "age": age,
        "grade": data.get("grade"),
        "gender": "male" if gender == 1 else "female",
        "screen_hours": screen_time,
        "usage_time": data.get("usage_time"),
        "usage_type": data.get("usage_type", []),
        "parent_goal": data.get("parent_goal"),
        "interests": data.get("interests", [])
    }

    return jsonify(response_data)


if __name__ == "__main__":
    app.run(debug=True)
