from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    """Returns a simple health status message."""
    return jsonify({
        "status": "UP",
        "service": "python-flask-service",
        "description": "Demonstrating automated Jenkins Multibranch CI/CD pipelines"
    }), 200

if __name__ == '__main__':
    # Run server on port 5000
    app.run(host='0.0.0.0', port=5000)
