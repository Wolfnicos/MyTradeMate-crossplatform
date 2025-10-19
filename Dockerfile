FROM python:3.10-slim

# Install TensorFlow 2.13 (compatible cu iOS!)
RUN pip install --no-cache-dir \
    tensorflow==2.13.0 \
    numpy \
    pandas \
    scikit-learn

WORKDIR /workspace

# Copy training scripts
COPY train_model.py /workspace/

CMD ["python", "train_model.py"]
