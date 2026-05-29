from pathlib import Path
from python.feature_verification.pipeline import SignatureVerificationPipeline
from sklearn.metrics.pairwise import cosine_similarity

p = SignatureVerificationPipeline.load('python_outputs/dummy_other_group/model.joblib')

sample = p.extractor.process_artifacts(Path('Dataset/a_(103)/1.png'), Path('Dataset/a_(103)/1.png'), label='test')
fv = sample.feature_vector

print('classes:', list(p.class_prototypes.keys()))
for k,v in p.class_prototypes.items():
    print(k, float(cosine_similarity(fv.reshape(1,-1), v.reshape(1,-1))[0][0]))

print('predicted_label:', str(p.model.predict(fv.reshape(1,-1))[0]))
print('similarity_to_enrolled a_(101):', p._similarity_to_enrolled(fv, 'a_(101)'))
print('similarity_overall_max:', p._similarity_to_enrolled(fv, None))
print('vector_norms (sample, prototypes):', float((fv**2).sum()**0.5), {k: float((v**2).sum()**0.5) for k,v in p.class_prototypes.items()})
