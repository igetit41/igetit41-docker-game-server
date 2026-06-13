import os

from flask import Flask, render_template_string, request
from google.cloud import compute_v1

app = Flask(__name__)

WAKE_TOKEN = os.environ.get("WAKE_TOKEN", "")
PROJECT = os.environ["GCP_PROJECT"]
ZONE = os.environ["INSTANCE_ZONE"]
INSTANCE = os.environ["INSTANCE_NAME"]

PAGE = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Wake game server</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 28rem; margin: 2rem auto; padding: 0 1rem; }
    label { display: block; margin-bottom: 0.5rem; }
    input[type="text"] { width: 100%; padding: 0.5rem; box-sizing: border-box; }
    button { margin-top: 0.75rem; padding: 0.5rem 1rem; }
    .message { margin-top: 1rem; padding: 0.75rem; background: #f4f4f4; border-radius: 4px; }
  </style>
</head>
<body>
  <h1>Wake game server</h1>
  <form method="post" action="/wake">
    <label for="code">Wake code</label>
    <input type="text" name="code" id="code" autocomplete="off" required>
    <button type="submit">Start server</button>
  </form>
  {% if message %}
  <p class="message">{{ message }}</p>
  {% endif %}
</body>
</html>
"""


def instance_client():
    return compute_v1.InstancesClient()


@app.get("/")
def index():
    return render_template_string(PAGE)


@app.post("/wake")
def wake():
    code = request.form.get("code", "").strip()
    if code != WAKE_TOKEN:
        return render_template_string(PAGE, message="Invalid code.")

    instance = instance_client().get(project=PROJECT, zone=ZONE, instance=INSTANCE)
    status = instance.status

    if status == "RUNNING":
        return render_template_string(PAGE, message="Server is already running.")

    if status == "TERMINATED":
        instance_client().start(project=PROJECT, zone=ZONE, instance=INSTANCE)
        return render_template_string(
            PAGE,
            message="Starting server. Allow a few minutes before connecting to the game.",
        )

    return render_template_string(PAGE, message=f"Server status: {status}. Try again shortly.")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
