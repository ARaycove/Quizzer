// // dart ml packages contain ready built functionality for simple ml and pre-processing, however it does not contain ready built models such as xgboost and other more complex models. So we will be coding this in raw dart from scratch using examples from scratch built xgboost class objects in python
// import 'package:quizzer/backend_systems/04_ml_modeling/relics/decision_tree_regressor.dart';
// import 'package:ml_dataframe/ml_dataframe.dart';
// import 'package:ml_linalg/linalg.dart';
// import 'dart:math';
// import 'dart:convert';

// /// Applies the methodology of gradient boosting machines Friedman 2001 for binary classification only. 
// /// Uses the Binary logistic loss function to calculate the negative derivative.
// /// 
// /// Input
// /// X: features dataframe
// /// y: target dataframe
// /// minLeaf: minimum number of samples needed to be classified as a node
// /// depth: sets the maximum depth allowed
// /// boostingRounds: number of boosting rounds or iterations
// /// 
// /// Output
// /// Gradient boosting machine that can be used for binary classification
// class XGBoostModel {
//   DataFrame? x;
//   DataFrame? y;
//   final int minLeaf;
//   final int depth;
//   final int boostingRounds;
  
//   late double learningRate;
//   late double basePred;
//   final List<DecisionTreeRegressor> estimators = [];
  
//   XGBoostModel({
//     this.x,
//     this.y,
//     required this.minLeaf,
//     required this.depth,
//     required this.boostingRounds,
//   });
  
//   static Vector sigmoid(Vector x) {
//     return x.mapToVector((val) => 1.0 / (1.0 + exp(-val)));
//   }
  
//   Vector negativeDerivativeLogLoss(Vector y, Vector logOdds) {
//     final p = sigmoid(logOdds);
//     return y - p;
//   }
  
//   static double logOdds(Vector column) {
//     final values = column.toList();
    
//     int binaryYes = 0;
//     int binaryNo = 0;
    
//     for (final value in values) {
//       if (value == 1) {
//         binaryYes++;
//       } else if (value == 0) {
//         binaryNo++;
//       }
//     }
    
//     final logOddsValue = log(binaryYes / binaryNo);
//     return logOddsValue;
//   }
  
//   void fit(DataFrame X, DataFrame y, {double learningRate = 0.1}) {
//     this.learningRate = learningRate;
    
//     // Log feature names and data types for debugging
//     // print('XGBoost fit - Feature columns: ${X.header.toList()}');
//     print('XGBoost fit - Target column: ${y.header.toList()}');
    
//     final yVector = y.toMatrix().getColumn(0);
//     basePred = logOdds(yVector);
    
//     Vector currentPred = Vector.filled(yVector.length, basePred);
    
//     for (int booster = 0; booster < boostingRounds; booster++) {
//       print('Training boosting round ${booster + 1}/$boostingRounds');
//       final pseudoResiduals = negativeDerivativeLogLoss(yVector, currentPred);
//       final boostingTree = DecisionTreeRegressor().fit(
//         X: X, 
//         y: pseudoResiduals, 
//         minLeaf: minLeaf, 
//         depth: depth
//       );
//       currentPred = currentPred + (boostingTree.predict(X) * learningRate);
//       estimators.add(boostingTree);
//     }
    
//     print('XGBoost model training completed successfully');
//   }
  
//   Vector predict(DataFrame X) {
//     Vector pred = Vector.filled(X.rows.length, 0.0);
    
//     for (final estimator in estimators) {
//       pred = pred + (estimator.predict(X) * learningRate);
//     }
    
//     // Add basePred (scalar) to each prediction
//     return pred + Vector.filled(X.rows.length, basePred);
//   }
  
//   /// Calculate accuracy: (TP + TN) / (TP + TN + FP + FN)
//   double calculateAccuracy(DataFrame xTest, DataFrame yTest) {
//     final predictions = predict(xTest);
//     final actualValues = yTest.toMatrix().getColumn(0);
    
//     final binaryPredictions = predictions.map((p) => sigmoid(Vector.fromList([p]))[0] >= 0.5 ? 1.0 : 0.0);
    
//     int correct = 0;
//     for (int i = 0; i < actualValues.length; i++) {
//       if (actualValues[i] == binaryPredictions.elementAt(i)) correct++;
//     }
    
//     return correct / actualValues.length;
//   }
  
//   /// Calculate precision: TP / (TP + FP)
//   double calculatePrecision(DataFrame xTest, DataFrame yTest) {
//     final predictions = predict(xTest);
//     final actualValues = yTest.toMatrix().getColumn(0);
    
//     final binaryPredictions = predictions.map((p) => sigmoid(Vector.fromList([p]))[0] >= 0.5 ? 1.0 : 0.0);
    
//     int tp = 0;
//     int fp = 0;
//     for (int i = 0; i < actualValues.length; i++) {
//       final predicted = binaryPredictions.elementAt(i);
//       final actual = actualValues[i];
      
//       if (predicted == 1.0) {
//         if (actual == 1.0) {
//           tp++;
//         } else {
//           fp++;
//         }
//       }
//     }
    
//     return tp == 0 && fp == 0 ? 0.0 : tp / (tp + fp);
//   }
  
//   /// Calculate recall: TP / (TP + FN)
//   double calculateRecall(DataFrame xTest, DataFrame yTest) {
//     final predictions = predict(xTest);
//     final actualValues = yTest.toMatrix().getColumn(0);
    
//     final binaryPredictions = predictions.map((p) => sigmoid(Vector.fromList([p]))[0] >= 0.5 ? 1.0 : 0.0);
    
//     int tp = 0;
//     int fn = 0;
//     for (int i = 0; i < actualValues.length; i++) {
//       final predicted = binaryPredictions.elementAt(i);
//       final actual = actualValues[i];
      
//       if (actual == 1.0) {
//         if (predicted == 1.0) {
//           tp++;
//         } else {
//           fn++;
//         }
//       }
//     }
    
//     return tp == 0 && fn == 0 ? 0.0 : tp / (tp + fn);
//   }
  
//   /// Calculate F1 Score: 2 * (precision * recall) / (precision + recall)
//   double calculateF1Score(DataFrame xTest, DataFrame yTest) {
//     final precision = calculatePrecision(xTest, yTest);
//     final recall = calculateRecall(xTest, yTest);
    
//     if (precision == 0.0 && recall == 0.0) return 0.0;
//     return 2 * (precision * recall) / (precision + recall);
//   }
  
//   /// Calculate confusion matrix [TN, FP, FN, TP]
//   List<int> calculateConfusionMatrix(DataFrame xTest, DataFrame yTest) {
//     final predictions = predict(xTest);
//     final actualValues = yTest.toMatrix().getColumn(0);
    
//     final binaryPredictions = predictions.map((p) => sigmoid(Vector.fromList([p]))[0] >= 0.5 ? 1.0 : 0.0);
    
//     int tn = 0;
//     int fp = 0;
//     int fn = 0;
//     int tp = 0;
    
//     for (int i = 0; i < actualValues.length; i++) {
//       final predicted = binaryPredictions.elementAt(i);
//       final actual = actualValues[i];
      
//       if (actual == 1.0 && predicted == 1.0) {
//         tp++;
//       } else if (actual == 1.0 && predicted == 0.0) {
//         fn++;
//       } else if (actual == 0.0 && predicted == 1.0) {
//         fp++;
//       } else if (actual == 0.0 && predicted == 0.0) {
//         tn++;
//       }
//     }
    
//     return [tn, fp, fn, tp];
//   }
  
//   /// Calculate log loss (binary cross-entropy)
//   double calculateLogLoss(DataFrame xTest, DataFrame yTest) {
//     final predictions = predict(xTest);
//     final actualValues = yTest.toMatrix().getColumn(0);
    
//     final probabilities = predictions.map((p) => sigmoid(Vector.fromList([p]))[0]);
    
//     double logLoss = 0.0;
//     for (int i = 0; i < actualValues.length; i++) {
//       final actual = actualValues[i];
//       final predicted = probabilities.elementAt(i);
      
//       final clippedPred = predicted.clamp(1e-15, 1 - 1e-15);
      
//       logLoss += -(actual * log(clippedPred) + (1 - actual) * log(1 - clippedPred));
//     }
    
//     return logLoss / actualValues.length;
//   }
  
//   /// Get all metrics in a single call
//   Map<String, double> assessAll(DataFrame xTest, DataFrame yTest) {
//     return {
//       'accuracy': calculateAccuracy(xTest, yTest),
//       'precision': calculatePrecision(xTest, yTest),
//       'recall': calculateRecall(xTest, yTest),
//       'f1_score': calculateF1Score(xTest, yTest),
//       'log_loss': calculateLogLoss(xTest, yTest),
//     };
//   }
  
//   /// Save model to JSON string
//   String toJson() {
//     final modelData = {
//       'minLeaf': minLeaf,
//       'depth': depth,
//       'boostingRounds': boostingRounds,
//       'learningRate': learningRate,
//       'basePred': basePred,
//       'estimators': estimators.map((estimator) => _serializeEstimator(estimator)).toList(),
//     };
//     return jsonEncode(modelData);
//   }
  
//   /// Load model from JSON string
//   static XGBoostModel fromJson(String jsonString) {
//     final Map<String, dynamic> data = jsonDecode(jsonString);
    
//     final model = XGBoostModel(
//       minLeaf: data['minLeaf'],
//       depth: data['depth'], 
//       boostingRounds: data['boostingRounds'],
//     );
    
//     model.learningRate = data['learningRate'];
//     model.basePred = data['basePred'][0];
    
//     for (final estimatorData in data['estimators']) {
//       model.estimators.add(_deserializeEstimator(estimatorData));
//     }
    
//     return model;
//   }
  
//   /// Serialize DecisionTreeRegressor to Map
//   Map<String, dynamic> _serializeEstimator(DecisionTreeRegressor estimator) {
//     return jsonDecode(estimator.toJson());
//   }
  
//   /// Deserialize DecisionTreeRegressor from Map  
//   static DecisionTreeRegressor _deserializeEstimator(Map<String, dynamic> data) {
//     return DecisionTreeRegressor.fromJson(jsonEncode(data));
//   }
// }