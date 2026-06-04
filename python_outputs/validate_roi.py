from pathlib import Path
import json
import cv2
import os
import numpy as np

ROOT = Path(__file__).parent
GROUP = ROOT / 'dummy_other_group'
CONTOUR = GROUP / 'contour'
FEATURE_READY = GROUP / 'feature_ready'
OUT = ROOT / 'roi_validation'
OUT.mkdir(parents=True, exist_ok=True)

results = {}

for class_dir in sorted(CONTOUR.iterdir()):
    if not class_dir.is_dir():
        continue
    rel_class = class_dir.name
    out_class = OUT / rel_class
    out_class.mkdir(parents=True, exist_ok=True)
    results[rel_class] = {}
    for img_path in sorted(class_dir.iterdir()):
        if not img_path.is_file():
            continue
        name = img_path.name
        contour_img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
        if contour_img is None:
            print(f"[WARN] unable to read {img_path}")
            continue
        # Threshold to isolate dark ink from the white background.
        # The contour artifacts are grayscale signature images, so non-zero != foreground.
        blurred = cv2.GaussianBlur(contour_img, (5, 5), 0)
        _, mask = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        kernel = np.ones((3, 3), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=1)

        # find contours on the ink mask
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        h, w = contour_img.shape[:2]
        if contours:
            filtered = [c for c in contours if cv2.contourArea(c) >= 20]
            target_contours = filtered if filtered else contours
            largest = max(target_contours, key=cv2.contourArea)
            x, y, ww, hh = cv2.boundingRect(largest)
        else:
            x, y, ww, hh = 0, 0, w, h
        results[rel_class][name] = [int(x), int(y), int(ww), int(hh)]

        # create overlay BGR
        overlay = cv2.cvtColor(contour_img, cv2.COLOR_GRAY2BGR)
        cv2.rectangle(overlay, (x, y), (x+ww, y+hh), (0,0,255), 2)
        # visualize detected ink mask for comparison
        mask_bgr = cv2.cvtColor(mask, cv2.COLOR_GRAY2BGR)

        # save overlay
        overlay_path = out_class / f"{name.replace('.png','')}_overlay.png"
        cv2.imwrite(str(overlay_path), overlay)

        mask_path = out_class / f"{name.replace('.png','')}_mask.png"
        cv2.imwrite(str(mask_path), mask_bgr)

        # save cropped ROI
        crop = contour_img[y:y+hh, x:x+ww]
        crop_path = out_class / f"{name.replace('.png','')}_crop.png"
        cv2.imwrite(str(crop_path), crop)

        # also copy feature_ready if exists
        feature_ready_path = FEATURE_READY / rel_class / name
        if feature_ready_path.exists():
            fr = cv2.imread(str(feature_ready_path), cv2.IMREAD_GRAYSCALE)
            if fr is not None:
                fr_out_path = out_class / f"{name.replace('.png','')}_featureready.png"
                cv2.imwrite(str(fr_out_path), fr)

print('[INFO] Done. Writing results.json')
with open(OUT / 'results.json','w',encoding='utf-8') as f:
    json.dump(results, f, indent=2)

print('[INFO] ROI validation completed. Outputs saved to:', OUT)
