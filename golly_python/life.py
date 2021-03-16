class Life(object):
    SMOL = 1e-12
    TOL = 1e-8

    RUNNING_AVG_WINDOW_SIZE = 240

    generation = 0
    columns = 0
    rows = 0
    livecells = 0
    livecells1 = 0
    livecells2 = 0
    victory = 0.0
    coverage = 0.0
    territory1 = 0.0
    territory2 = 0.0

    found_victor = False
    running_avg_window: list = []
    running_avg_last3: list = [0.0, 0.0, 0.0]
    running = False

    def __init__(self, s1, s2, rows, columns, neighbor_color_legacy_mode = False):

