import torch
import torch.nn as nn
import torch.nn.functional as F

class SignatureCNN(nn.Module):
    """
    A lightweight Convolutional Neural Network for extracting signature embeddings.
    Designed to run efficiently on CPU for student projects.
    """
    def __init__(self, embedding_dim=128):
        super(SignatureCNN, self).__init__()
        # Input: 1 channel (grayscale), output: 16 channels
        self.conv1 = nn.Conv2d(1, 16, kernel_size=3, stride=1, padding=1)
        self.pool = nn.MaxPool2d(kernel_size=2, stride=2, padding=0)
        
        self.conv2 = nn.Conv2d(16, 32, kernel_size=3, stride=1, padding=1)
        self.conv3 = nn.Conv2d(32, 64, kernel_size=3, stride=1, padding=1)
        
        # Adaptive pooling ensures the output is always 4x4 regardless of input image size
        self.adaptive_pool = nn.AdaptiveAvgPool2d((4, 4))
        
        # Fully connected layers
        self.fc1 = nn.Linear(64 * 4 * 4, 256)
        self.fc2 = nn.Linear(256, embedding_dim)
        
        self.dropout = nn.Dropout(p=0.3)

    def forward(self, x):
        # x shape should be (batch_size, 1, height, width)
        x = self.pool(F.relu(self.conv1(x)))
        x = self.pool(F.relu(self.conv2(x)))
        x = self.pool(F.relu(self.conv3(x)))
        
        x = self.adaptive_pool(x)
        x = torch.flatten(x, 1)
        
        x = F.relu(self.fc1(x))
        x = self.dropout(x)
        x = self.fc2(x)
        
        # L2 Normalize the output so that cosine similarity can be easily computed
        embeddings = F.normalize(x, p=2, dim=1)
        return embeddings
