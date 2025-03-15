import math
from datetime import timedelta, datetime
import sys
import stddraw

# Solve Sinusoidal
def solve_sinusoidal(theta,
                     amplitude = 1,
                     B    = 1,
                     h    = 0,
                     k    = 0
                     ):
    A = amplitude
    θ = theta
    B = 1
    h = 0
    k = 0
    pos_neg = 1 # or -1
    solution = pos_neg * A * math.sin()* (B*(θ-h)) + k
    print(solution)

def attempt_solve_alpha(a = None, beta = None, b = None, c = None, epsilon = None):
    '''
    supply the sides and angles known, output is the other sides in a print statement
    provides all possible solutions
    '''
    # try using other angles
    if beta != None and epsilon != None:
        alpha = 180 - (beta+epsilon)
        return alpha
    # try using law of sines
    if a != None and beta != None and b != None:
        alpha = math.degrees(
            math.asin(
                (a*math.sin(math.radians(beta)))/b
                )
            )
        return alpha
    if a != None and epsilon != None and c != None:
        alpha = math.degrees(
            math.asin(
                (a*math.sin(math.degrees(epsilon)))/c
            )
        )
        return alpha
    # try using law of cosines
    else:
        return None
def attempt_solve_beta():
    pass
def attempt_solve_epsilon():
    pass
def attempt_solve_side_a():
    pass
def attempt_solve_side_b():
    pass
def attempt_solve_side_c():
    pass
    

def solve_triangle(a = None, b = None, c = None, alpha = None, beta = None, epsilon = None):
    '''
    Angles should be provided in degrees
    '''
    # law of sines
    # law of cosines
    while True:
        alpha       = attempt_solve_alpha(a, beta, b, c, epsilon)    
        beta        = attempt_solve_beta()
        epsilon     = attempt_solve_epsilon()
        a           = attempt_solve_side_a()
        b           = attempt_solve_side_b()
        c           = attempt_solve_side_c()

        if (a       != None and
            b       != None and
            c       != None and
            alpha   != None and
            beta    != None and
            epsilon != None):
            print("something")


def memory_formula(x):
    question_object = {}
    question_object["time_between_revisions"] = 0.37
    question_object["revision_streak"] = 5
    h = 4.5368 # horizontal shift
    k = question_object["time_between_revisions"] # constant, initial value of 1.37
    t = 36500 #days Maximum length of human memory (approximately one human lifespan)


    numerator   = math.pow(math.e, (k*(x-h)))
    denominator = 1 + (numerator/t)
    fraction = numerator/denominator
    def calc_g(h, k, t):
        num = math.pow(math.e, (k*(0-h)))
        denom = 1 + (numerator/t)
        fraction = num/denom
        return -fraction
    g = calc_g(h, k, t)
    
    number_of_days = fraction+g
    return number_of_days


# for x in range(0, 31):
#     num_days = memory_formula(x)
#     if num_days != 0 or num_days != 0.0:
#         avg_shown = 1 / num_days
#         next_due_date = datetime.now() + timedelta(days=num_days)
#         print(f"{x:5} reps: {num_days:10.2f}, next_due: {next_due_date}")
def draw_sin_rose(n = None):
    d_t = 0.001
    theta = 0
    if n == None:
        n=6
    stddraw.setXscale(-1,1)
    stddraw.setYscale(-1,1)
    while theta <= math.pi*2: #custom range -> range only works with integer values
        # Polar equation
        radius = math.sin(n*theta)
        # Determine cartesian coordinates
        x = radius * math.cos(theta)
        y = radius * math.sin(theta)
        # Plot point
        stddraw.point(x, y)
        theta += d_t # increment step
    stddraw.show()

def natlog(x):
    print(x, math.log(x))

x_val = [1, 2, 5, 10]

for i in x_val:
    natlog(i)
    