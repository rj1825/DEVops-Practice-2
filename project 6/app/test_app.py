import unittest
import json
from app import app

class FlaskAppTestCase(unittest.TestCase):
    def setUp(self):
        # Configure test client
        self.app = app.test_client()
        self.app.testing = True

    def test_home_endpoint(self):
        # Send GET request to /
        response = self.app.get('/')
        
        # Verify status code
        self.assertEqual(response.status_code, 200)
        
        # Parse JSON data
        data = json.loads(response.data.decode('utf-8'))
        
        # Verify JSON keys and values
        self.assertEqual(data.get('status'), 'UP')
        self.assertEqual(data.get('service'), 'python-flask-service')
        self.assertIn('Jenkins', data.get('description'))

if __name__ == '__main__':
    unittest.main()
