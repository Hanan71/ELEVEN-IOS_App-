from flask import Flask, request, jsonify
import pickle
import numpy as np
import os
import google.generativeai as genai

#  API Key
os.environ["API_KEY"] = "AQ.Ab8RN6KfkKCZQ_hzaKuE25BapYsbaiFVVI0oc62cX3tmp1zJlg"

genai.configure(api_key=os.getenv("API_KEY"))
model_ai = genai.GenerativeModel("gemini-pro")

app = Flask(__name__)

model = pickle.load(open("model.pkl", "rb"))

# number to risk kind
def map_prediction(pred):
    return ["low", "medium", "high"][pred]

#  build prompt 
def build_prompt(data):
    return f"""
You are a parenting expert specializing in reducing children's screen addiction.

Child profile:

- Age: {data['age']}
- Screen time: {data['screen_hours']} hours daily
- Usage time: {data['usage_time']}
- Usage type: {", ".join(data['usage_type'])}
- Interests: {", ".join(data['interests'])}
- Parent goal: {data['parent_goal']}
- Risk level: {data['risk']}

Your task:
Create a personalized action plan for parents.

Rules:
- Give 4 to 6 bullet points
- Be specific and actionable
- Use child's interests
- Adjust based on risk level
- Keep it simple
- Bullet points only
"""

# 🔥 AI call
def call_ai(prompt):
    response = model_ai.generate_content(
        prompt,
        generation_config={
            "max_output_tokens": 80,
            "temperature": 0.5
        }
    )

    return response.text.split("\n")[:4]  # shorten

@app.route("/")
def home():
    return "API is running"

@app.route("/predict", methods=["POST"])
def predict():
    data = request.json

    # model info
    age = int(data["age"])
    gender = int(data["gender"])  # 0 or 1
    screen_time = float(data["screen_time"])

    features = np.array([[age, gender, screen_time]])

    # prediction
    prediction = model.predict(features)[0]
    risk = map_prediction(prediction)

    # AI data
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

    # 🔥 AI plan
    prompt = build_prompt(response_data)
    plan = call_ai(prompt)

    return jsonify({
        "risk": risk,
        "plan": plan,
        "data": response_data
    })

if __name__ == "__main__":
    app.run(debug=True)
    
