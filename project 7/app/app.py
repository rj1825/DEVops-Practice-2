from flask import Flask, jsonify

app = Flask(__name__)

# Active version of the microservice (updated during builds)
VERSION = "1.0.1"

@app.route('/')
def home():
    """Returns a simple GitOps status response."""
    return jsonify({
        "status": "UP",
        "service": "gitops-flask-service",
        "version": VERSION,
        "description": "Continuous Delivery managed via Jenkins and ArgoCD"
    }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
