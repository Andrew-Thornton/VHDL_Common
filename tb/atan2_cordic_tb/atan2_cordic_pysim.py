from math import atan2, sqrt, sin, cos, radians, degrees, pi

ITERS = 32
theta_table = [(atan2(1, 2**i))/pi for i in range(ITERS)]


def cordic_atan2(y: float, x: float, n: int = ITERS) -> float:
    """
    CORDIC vectoring mode: compute atan2(y, x).

    Instead of rotating toward a target angle (rotation mode), vectoring mode
    rotates the input vector (x, y) toward the positive x-axis (i.e. drives y
    to zero), accumulating the total angle rotated.  That accumulated angle is
    exactly atan2(y, x).

    The quadrant pre-/post-correction handles inputs outside (-pi/2, pi/2):
      - If x < 0 and y >= 0  →  result is in Q2, add  pi after CORDIC.
      - If x < 0 and y <  0  →  result is in Q3, subtract pi after CORDIC.
    """
    assert n <= ITERS

    # Quadrant correction: CORDIC vectoring only converges for |angle| < pi/2,
    # i.e. when x > 0.  Flip the vector into the right half-plane first.
    if x < 0:
        quadrant_offset = +1.0 if y >= 0 else -1.0
        x, y = -x, -y # note in code this is x_s 0
    else:
        quadrant_offset = 0.0

    theta = 0.0
    P2i = 1.0
    for arc_tangent in theta_table[:n]:
        # Drive y toward zero: rotate clockwise if y > 0, counter-clockwise if y < 0.
        sigma = +1 if y > 0 else -1
        theta += sigma * arc_tangent
        xprev = x
        yprev = y
        #goes x_s 1 to 
        x = xprev + (sigma * yprev * P2i)
        y = yprev - (sigma * xprev * P2i)
        P2i /= 2

    # Note: the K factor cancels out in vectoring mode because we only care
    # about the accumulated angle, not the magnitude of (x, y).
    return theta + quadrant_offset

if __name__ == "__main__":
    print("=== CORDIC vectoring mode: atan2 ===")
    print("  y          x          atan2(y,x)   diff.(rad)   expected (rad)")
    test_cases = [
        (0, 1), (1, 1), (1, 0), (1, -1),
        (0, -1), (-1, -1), (-1, 0), (-1, 1),
        (sin(radians(30)), cos(radians(30))),
        (sin(radians(-45)), cos(radians(-45))),
        (sin(radians(120)), cos(radians(120))),
        (sin(radians(-150)), cos(radians(-150))),
    ]
    for y, x in test_cases:
        result   = cordic_atan2(y, x)
        expected = (atan2(y, x))/pi
        print(f"  y={y:+.4f}  x={x:+.4f}  {result:+.8f}  ({result-expected:+.2e})   {expected:+.8f}")