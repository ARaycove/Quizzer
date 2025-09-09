```python
import numpy as np

import matplotlib_inline

import matplotlib.pyplot as plt

from sklearn import datasets

from sklearn.model_selection import train_test_split

from sklearn.neighbors import KNeighborsClassifier

from sklearn.metrics import accuracy_score

import math

np.random.seed(1234)

dataset = datasets.load_iris()

# define the metric we will use to measure similarity

highest = 0

x, y = dataset['data'][:, :2], dataset['target']

(N,D), C = x.shape, np.max(y)+1

# for i in range(1,500000):

x_train, x_test, y_train, y_test = train_test_split(x, y, test_size=0.3333, random_state= 16332)

model = KNeighborsClassifier(n_neighbors=3)

  

y_pred= model.fit(x_train, y_train).predict(x_test)

  

accuracy = model.score(x_test, y_test) * 100

print(f"accuracy is: {accuracy}")

  

# if accuracy > highest:

# highest = accuracy

# print(f"rs: {i} with accuracy: {accuracy}")
```

accuracy is 94.0% with seed 16332,
variance is about 20%, meaning depending on what configuration of train/test set we use, accuracy will vary by 20%.

I calculated the euclidean distance a bit different than the formula provided, as there was a mismatch in shape (np.sqrt doesn't have the axis=-1 parameter)
```python
euclidean = lambda x1, x2: np.linalg.norm(x2-x1, axis=-1)
```
  The documentation for np.linalg.norm essentially is doing the euclidean distance calculation, however the docs for this function do not explicitly say it can be used for euclidean distance calculation

########################################################

# Old Code:
```
# print(f'instance (N) \t {N} \n features (D) \t {D} \n classes (C) \t {C}')

  

# x_train, y_train = x[inds[:100]], y[inds[:100]]

# x_test, y_test = x[inds[100:]], y[inds[100:]]

  
  

# plt.scatter(x_train[:,0], x_train[:,1], c=y_train, marker = 'o', label='train')

# plt.scatter(x_test[:,0], x_test[:,1], c=y_test, marker='s', label='test')

# plt.legend()

# plt.ylabel('sepal length')

# plt.xlabel('sepal width')

# plt.show() #show results

  

# manhattan = lambda x1, x2: np.sum(np.abs(x2 - x1), axis=-1)

# euclidean = lambda x1, x2: np.linalg.norm(x2-x1, axis=-1)
  

# class KNN:
# def __init__(self, K=1, dist_fn=manhattan):
# self.dist_fn = dist_fn
# self.K = K
# return
# def fit(self, x, y):
# '''Store the training data using this method as it is a lazy learner'''
# self.x = x
# self.y = y
# self.C = np.max(y) + 1
# return self
# def predict(self, x_test):

# '''Makes a prediction using the stored training data and the test data given as argument'''

# num_test = x_test.shape[0]
# distances = self.dist_fn(self.x[None,:,:], x_test[:,None,:])
# #ith-row of knns store the indices of k closest training samples to the ith-test sample
# knns = np.zeros((num_test, self.K), dtype=int)
# #ith-row of y_prob has the probability distribution over C classes
# y_prob = np.zeros((num_test, self.C))
# for i in range(num_test):
# knns[i,:] = np.argsort(distances[i])[:self.K]
# y_prob[i,:] = np.bincount(self.y[knns[i,:]], minlength=self.C) #counts the number of instances of each class in the K-closest training samples
# y_prob /= np.sum(y_prob, axis=-1, keepdims=True)
# # simply divide by K to get a probability distribution
# y_prob /= self.K
# return y_prob, knns
# print('knns shape :', knns.shape)
# print('y_prob shape:', y_prob.shape)

# # To get hard predictions by choosing the class with the maximum probability
# #boolean array to later slice the indexes of correct and incorrect predictions
# correct = y_test == y_pred
# incorrect = np.logical_not(correct)

# #visualization of the points
# plt.scatter(x_train[:,0], x_train[:,1], c=y_train, marker='o', alpha=.2, label='train')
# plt.scatter(x_test[correct,0], x_test[correct,1], marker='.', c=y_pred[correct], label='correct')
# plt.scatter(x_test[incorrect,0], x_test[incorrect,1], marker='x', c=y_test[incorrect], label='misclassified')

# #connect each node to k-nearest neighbours in the training set
# for i in range(x_test.shape[0]):
# for k in range(model.K):
# hor = x_test[i,0], x_train[knns[i,k],0]
# ver = x_test[i,1], x_train[knns[i,k],1]
# plt.plot(hor, ver, 'k-', alpha=.1)
# plt.ylabel('sepal length')
# plt.xlabel('sepal width')
# plt.legend()
# # plt.show() 

# #we can make the grid finer by increasing the number of samples from 200 to higher value
# x0v = np.linspace(np.min(x[:,0]), np.max(x[:,0]), 200)
# x1v = np.linspace(np.min(x[:,1]), np.max(x[:,1]), 200)

# #to features values as a mesh
# x0, x1 = np.meshgrid(x0v, x1v)
# x_all = np.vstack((x0.ravel(),x1.ravel())).T

# for k in range(1,4):
# model = KNN(K=k)

# y_train_prob = np.zeros((y_train.shape[0], C))
# y_train_prob[np.arange(y_train.shape[0]), y_train] = 1

# #to get class probability of all the points in the 2D grid
# y_prob_all, _ = model.fit(x_train, y_train).predict(x_all)

# y_pred_all = np.zeros_like(y_prob_all)
# y_pred_all[np.arange(x_all.shape[0]), np.argmax(y_prob_all, axis=-1)] = 1

# plt.scatter(x_train[:,0], x_train[:,1], c=y_train_prob, marker='o', alpha=1)
# plt.scatter(x_all[:,0], x_all[:,1], c=y_pred_all, marker='.', alpha=0.01)
# plt.ylabel('sepal length')
# plt.xlabel('sepal width')
# # plt.show()
```