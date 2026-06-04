import requests
from pathlib import Path

API_URL = 'http://127.0.0.1:8000/infer'
CONTOUR = Path('python_outputs/dummy_other_group/contour/a_(101)/1.png')
FEATURE = Path('python_outputs/dummy_other_group/feature_ready/a_(101)/1.png')

with open(CONTOUR,'rb') as c, open(FEATURE,'rb') as f:
    files = {
        'contour': (CONTOUR.name, c, 'image/png'),
        'feature_ready': (FEATURE.name, f, 'image/png')
    }
    resp = requests.post(API_URL, files=files, data={'enrolled_label':'a_(101)'})
    print('status', resp.status_code)
    print(resp.json())
