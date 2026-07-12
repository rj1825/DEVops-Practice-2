import unittest
import json
from app import app

class FlaskAppTestCase(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_home_endpoint(self):
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        
        data = json.loads(response.data.decode('utf-8'))
        self.assertEqual(data.get('status'), 'UP')
        self.assertEqual(data.get('service'), 'gitops-flask-service')
        self.assertTrue(data.get('version') is not None and len(data.get('version')) > 0)
        self.assertIn('ArgoCD', data.get('description'))

if __name__ == '__main__':
    unittest.main()
