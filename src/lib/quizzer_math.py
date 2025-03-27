import numpy as np

def calculate_combinations(n, r):
    """
    Calculate the number of ways to select r items from n items without replacement and without order.
    
    Parameters:
    n (int): Total number of items
    r (int): Number of items to select
    
    Returns:
    int: Number of possible combinations
    """
    # Using scipy.special.comb for numerical stability with large numbers
    # This is more reliable than calculating factorials directly
    return int(np.math.comb(n, r))

def find_optimal_pattern_size(n):
    """
    Find the optimal pattern size r that maximizes C(n,r) for a given n
    
    Parameters:
    n (int): Total number of items (neurons)
    
    Returns:
    tuple: (optimal_r, max_combinations)
    """
    combinations = []
    for r in range(1, n//2 + 1):  # Only need to check up to n/2 due to symmetry
        combinations.append((r, calculate_combinations(n, r)))
    
    optimal_r, max_combinations = max(combinations, key=lambda x: x[1])
    return optimal_r, max_combinations

# Example usage for your specific case
n_neurons = 32  # Total neurons in output layer

(optimal_r, max_combinations) = find_optimal_pattern_size(n_neurons)

print(f"optimal pattern size: {optimal_r}")
print(f"r gives: {max_combinations:2e}|{max_combinations} ")

n, r = 6000000, 10
print(f"At size of set {r} gives: {calculate_combinations(n, r)} combination groups")