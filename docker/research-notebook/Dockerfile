FROM jupyter/datascience-notebook:latest

USER root
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

USER jovyan

# Install Ray and ML libraries
RUN pip install --no-cache-dir \
    ray[default]==2.41.0 \
    ray[train] \
    ray[tune] \
    mlflow \
    transformers \
    pytorch-lightning \
    optuna \
    wandb

# Set default environment variables
ENV RAY_ADDRESS="ray://ray-client-service.ray-training-dev.svc.cluster.local:10001"
ENV MLFLOW_TRACKING_URI="http://mlflow-service.ray-training-dev.svc.cluster.local:5000"
