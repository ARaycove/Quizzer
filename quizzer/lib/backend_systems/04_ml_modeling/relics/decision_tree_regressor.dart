// import 'package:ml_dataframe/ml_dataframe.dart';
// import 'package:ml_linalg/linalg.dart';
// import 'dart:math';
// import 'dart:convert';

// /// Production-ready Node that stores only decision rules, no training data
// class Node {
//   final int? varIdx;           // Feature index to split on (null for leaf)
//   final double? split;         // Split threshold (null for leaf)
//   final double val;            // Prediction value (leaf) or intermediate value
//   final bool isLeaf;
  
//   Node? lhs;
//   Node? rhs;
  
//   /// Constructor for leaf nodes
//   Node.leaf(this.val) : 
//     varIdx = null, 
//     split = null, 
//     isLeaf = true;
  
//   /// Constructor for split nodes  
//   Node.split(this.varIdx, this.split, this.val) : isLeaf = false;
  
//   /// Build tree from training data
//   static Node buildTree(DataFrame x, Vector y, List<int> idxs, int minLeaf, int depth) {
//     final rowCount = idxs.length;
//     final colCount = x.header.length;
    
//     // Compute leaf value
//     final gradientValues = idxs.map((i) => y[i]).toList();
//     final leafVal = gradientValues.reduce((a, b) => a + b) / gradientValues.length;
    
//     // Check stopping criteria
//     if (depth <= 0 || rowCount < minLeaf * 2) {
//       return Node.leaf(leafVal);
//     }
    
//     // Find best split
//     double bestScore = double.negativeInfinity;
//     int? bestVarIdx;
//     double? bestSplit;
//     List<int>? bestLhsIndices;
//     List<int>? bestRhsIndices;
    
//     for (int varIdx = 0; varIdx < colCount; varIdx++) {
//       final columnValues = _getColumnValues(x, idxs, varIdx);
      
//       for (int r = 0; r < rowCount; r++) {
//         final splitValue = columnValues[r];
//         final lhsIndices = <int>[];
//         final rhsIndices = <int>[];
        
//         for (int i = 0; i < rowCount; i++) {
//           final idx = idxs[i];
//           if (columnValues[i] <= splitValue) {
//             lhsIndices.add(idx);
//           } else {
//             rhsIndices.add(idx);
//           }
//         }
        
//         if (lhsIndices.length < minLeaf || rhsIndices.length < minLeaf) continue;
        
//         final score = _calculateGain(y, lhsIndices, rhsIndices);
//         if (score > bestScore) {
//           bestScore = score;
//           bestVarIdx = varIdx;
//           bestSplit = splitValue;
//           bestLhsIndices = lhsIndices;
//           bestRhsIndices = rhsIndices;
//         }
//       }
//     }
    
//     // No valid split found
//     if (bestVarIdx == null) {
//       return Node.leaf(leafVal);
//     }
    
//     // Create split node
//     final node = Node.split(bestVarIdx, bestSplit!, leafVal);
//     node.lhs = buildTree(x, y, bestLhsIndices!, minLeaf, depth - 1);
//     node.rhs = buildTree(x, y, bestRhsIndices!, minLeaf, depth - 1);
    
//     return node;
//   }
  
//   /// Get column values for indices
//   static List<double> _getColumnValues(DataFrame x, List<int> idxs, int varIdx) {
//     final matrix = x.toMatrix();
//     return idxs.map((rowIdx) => matrix[rowIdx][varIdx].toDouble()).toList();
//   }
  
//   /// Calculate gain for split
//   static double _calculateGain(Vector y, List<int> lhsIndices, List<int> rhsIndices) {
//     double lhsSum = 0;
//     double rhsSum = 0;
    
//     for (final idx in lhsIndices) {
//       lhsSum += y[idx];
//     }
//     for (final idx in rhsIndices) {
//       rhsSum += y[idx];
//     }
    
//     final totalSum = lhsSum + rhsSum;
//     final totalCount = lhsIndices.length + rhsIndices.length;
    
//     return (pow(lhsSum, 2) / lhsIndices.length) +
//            (pow(rhsSum, 2) / rhsIndices.length) -
//            (pow(totalSum, 2) / totalCount);
//   }
  
//   /// Predict single row - NO TRAINING DATA NEEDED
//   double predictRow(List<double> features) {
//     if (isLeaf) return val;
    
//     final featureValue = features[varIdx!];
//     final node = featureValue <= split! ? lhs! : rhs!;
//     return node.predictRow(features);
//   }
  
//   /// Serialize to JSON
//   Map<String, dynamic> toJson() {
//     return {
//       'varIdx': varIdx,
//       'split': split,
//       'val': val,
//       'isLeaf': isLeaf,
//       'lhs': lhs?.toJson(),
//       'rhs': rhs?.toJson(),
//     };
//   }
  
//   /// Deserialize from JSON - NO TRAINING DATA NEEDED
//   static Node fromJson(Map<String, dynamic> json) {
//     final node = json['isLeaf'] 
//       ? Node.leaf(json['val'])
//       : Node.split(json['varIdx'], json['split'], json['val']);
    
//     if (json['lhs'] != null) {
//       node.lhs = Node.fromJson(json['lhs']);
//     }
//     if (json['rhs'] != null) {
//       node.rhs = Node.fromJson(json['rhs']);
//     }
    
//     return node;
//   }
// }

// /// Production-ready DecisionTreeRegressor
// class DecisionTreeRegressor {
//   Node? dtree;
  
//   /// Fit the decision tree regressor
//   DecisionTreeRegressor fit({
//     required DataFrame X, 
//     required Vector y, 
//     int minLeaf = 5, 
//     int depth = 5
//   }) {
//     final indices = List.generate(y.length, (i) => i);
//     dtree = Node.buildTree(X, y, indices, minLeaf, depth);
//     return this;
//   }
  
//   /// Predict - NO TRAINING DATA NEEDED
//   Vector predict(DataFrame X) {
//     if (dtree == null) throw Exception('Model must be fitted before prediction');
    
//     final matrix = X.toMatrix();
//     final predictions = <double>[];
    
//     for (int i = 0; i < matrix.rowsNum; i++) {
//       final row = List.generate(matrix.columnsNum, (j) => matrix[i][j].toDouble());
//       predictions.add(dtree!.predictRow(row));
//     }
    
//     return Vector.fromList(predictions);
//   }
  
//   /// Serialize to JSON
//   String toJson() {
//     if (dtree == null) throw Exception('Model must be fitted before serialization');
//     return jsonEncode({
//       'type': 'DecisionTreeRegressor',
//       'dtree': dtree!.toJson(),
//     });
//   }
  
//   /// Deserialize from JSON - NO TRAINING DATA NEEDED
//   static DecisionTreeRegressor fromJson(String jsonString) {
//     final Map<String, dynamic> data = jsonDecode(jsonString);
    
//     final regressor = DecisionTreeRegressor();
//     regressor.dtree = Node.fromJson(data['dtree']);
    
//     return regressor;
//   }
// }