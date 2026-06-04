import re
import subprocess
from pathlib import Path
import cv2
import numpy as np
import itertools

ROOT = Path(__file__).parent
SAMPLES = ROOT / 'dummy_other_group' / 'contour'

def run_flutter_test():
    cmd = ['flutter','test','test/roi_compare_test.dart','-r','expanded']
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
        return proc.stdout
    except FileNotFoundError:
        # flutter not available in PATH (common on CI or different env)
        # try to read previously captured output file
        fallback = ROOT / 'flutter_roi_output.txt'
        if fallback.exists():
            return fallback.read_text(encoding='utf-16', errors='ignore')
        raise


def parse_flutter_output(txt):
    # lines like: a_(101)/1.png | full=[185, 91, 414, 408] | inkOnly=[...] | python=[184, 91, 416, 409]
    mapping = {}
    for line in txt.splitlines():
        m = re.search(r"([\w\(\)_\-/]+\.png) \| full=\[(\d+), (\d+), (\d+), (\d+)\] .* \| python=\[(.*?)\]", line)
        if m:
            key = m.group(1)
            fx = list(map(int, [m.group(2), m.group(3), m.group(4), m.group(5)]))
            pyraw = m.group(6)
            py = None
            try:
                py = list(map(int, [s.strip() for s in pyraw.split(',')]))
            except:
                py = None
            mapping[key] = fx
    return mapping


def detect_bbox_opencv(img_path, blur_k, open_iter, close_iter, min_contour_area, select_by='bbox'):
    im = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
    if im is None:
        return None
    b = cv2.GaussianBlur(im, (blur_k, blur_k), 0)
    _, mask = cv2.threshold(b, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    kernel = np.ones((3,3), np.uint8)
    if open_iter>0:
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=open_iter)
    if close_iter>0:
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=close_iter)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        h,w = im.shape
        return (0,0,w,h)
    best = None
    best_metric = -1
    for c in contours:
        x,y,wc,hc = cv2.boundingRect(c)
        area = wc*hc
        cac = cv2.contourArea(c)
        if select_by=='bbox':
            metric = area
        else:
            metric = cac
        if area < min_contour_area:
            continue
        if metric > best_metric:
            best_metric = metric
            best = (x,y,wc,hc)
    if best is None:
        # fallback largest bbox
        c = max(contours, key=cv2.contourArea)
        x,y,wc,hc = cv2.boundingRect(c)
        return (x,y,wc,hc)
    return best


def iou(boxA, boxB):
    if boxA is None or boxB is None:
        return 0.0
    xA,yA,wA,hA = boxA
    xB,yB,wB,hB = boxB
    x1 = max(xA, xB)
    y1 = max(yA, yB)
    x2 = min(xA+wA, xB+wB)
    y2 = min(yA+hA, yB+hB)
    if x2<=x1 or y2<=y1:
        return 0.0
    inter = (x2-x1)*(y2-y1)
    union = wA*hA + wB*hB - inter
    return inter/union if union>0 else 0.0


def main():
    print('[INFO] Running Flutter test to collect reference bbox...')
    out = run_flutter_test()
    refs = parse_flutter_output(out)
    if not refs:
        print('[ERROR] No Flutter bbox parsed. Output snippet:\n', out[:1000])
        return
    print(f'[INFO] Parsed {len(refs)} reference boxes from Flutter test')

    images = []
    for cls in sorted(SAMPLES.iterdir()):
        if not cls.is_dir(): continue
        for f in sorted(cls.iterdir()):
            if f.suffix.lower()=='.png':
                key = f'{cls.name}/{f.name}'
                if key in refs:
                    images.append((key,f))
    print(f'[INFO] Found {len(images)} images to evaluate')

    blur_options = [3,5,7]
    open_options = [0,1,2]
    close_options = [0,1,2]
    min_area_options = [0,20,50,200]
    select_opts = ['bbox','contour']

    best = None
    best_score = -1
    results = []
    combos = list(itertools.product(blur_options, open_options, close_options, min_area_options, select_opts))
    print(f'[INFO] Trying {len(combos)} parameter combinations')

    for (blur_k, open_it, close_it, min_area, sel) in combos:
        scores = []
        for key,fpath in images:
            cand = detect_bbox_opencv(fpath, blur_k, open_it, close_it, min_area, select_by=sel)
            ref = refs.get(key)
            score = iou(cand, ref)
            scores.append(score)
        mean_iou = float(np.mean(scores))
        results.append(((blur_k, open_it, close_it, min_area, sel), mean_iou))
        if mean_iou > best_score:
            best_score = mean_iou
            best = (blur_k, open_it, close_it, min_area, sel)
    results.sort(key=lambda x: x[1], reverse=True)

    print(f'[RESULT] Best mean IoU={best_score:.4f} params={best}')
    print('[TOP 5]')
    for p,s in results[:5]:
        print(p, s)

if __name__=='__main__':
    main()
