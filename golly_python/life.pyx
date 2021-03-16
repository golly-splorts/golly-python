# cython: language_level=3
# cython: boundscheck=False
# cython: wraparound=False
# cython: initializedcheck=False
# cython: cdivision = True
# cython: always_allow_keywords =False
# cython: unraisable_tracebacks = False
# cython: binding = False

from libc.stdlib cimport rand
from libcpp.vector cimport vector
from cpython cimport array
import cython
cimport numpy as np


cdef class LiveCount:

    cdef int generation
    cdef int liveCells
    cdef int liveCells1
    cdef int liveCells2
    cdef float victoryPct
    cdef float coverage
    cdef float territory1
    cdef float territory2

    def __cinit__(self,
        int generation,
        int liveCells,
        int liveCells1,
        int liveCells2,
        float victoryPct,
        float coverage,
        float territory1,
        float territory2
    ):
        self.generation = generation
        self.liveCells  = liveCells
        self.liveCells1 = liveCells1
        self.liveCells2 = liveCells2
        self.victoryPct = victoryPct
        self.coverage   = coverage
        self.territory1 = territory1
        self.territory2 = territory2


cdef class Life:

    cdef vector[vector[int]] actual_state
    cdef vector[vector[int]] actual_state1
    cdef vector[vector[int]] actual_state2

    cdef vector[vector[int]] redraw_list

    cdef int who_won
    cdef bint found_victor

    cdef int generation, columns, rows
    cdef int livecells, livecells1, livecells2
    cdef float victory, coverage, territory1, territory2

    cdef float* running_avg_window
    cdef float[3] running_avg_last3
    cdef float SMOL, TOL
    cdef int RUNNING_AVG_WINDOW_SIZE

    cdef int top_pointer, bottom_pointer
    cdef bint running

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

    def __cinit__(self, dict s1, dict s2, int rows, int columns, bint neighbor_color_legacy_mode = False):
        self.SMOL = 1e-12
        self.TOL = 1e-8
        self.running = False

        self.RUNNING_AVG_WINDOW_SIZE = 240
        self.running_avg_window = <float*> PyMem_Malloc(self.RUNNING_AVG_WINDOW_SIZE * sizeof(float))
        for i in range(self.RUNNING_AVG_WINDOW_SIZE):
            self.running_avg_window[i] = 0.0

        for i in range(3):
            self.runing_avg_last3[i] = 0.0

        self.generations = 0
        self.rows = rows
        self.columns = columns

        self.livecells = 0
        self.livecells1 = 0
        self.livecells2 = 0

        self.victory = 0.0
        self.coverage = 0.0
        self.territory1 = 0.0
        self.territory2 = 0.0
        self.neighbor_color_legacy_mode = neighbor_color_legacy_mode

        # We expect the manager class to parse the JSON
        for s1row in s1:
            for y in s1row:
                yy = int(y)
                for xx in s1row[y]:
                    self.add_cell_inplace(xx, yy, self.actual_state)
                    self.add_cell_inplace(xx, yy, self.actual_state1)
        
        for s2row in s2:
            for y in s2row:
                yy = int(y)
                for xx in s2row[y]:
                    self.add_cell_inplace(xx, yy, self.actual_state)
                    self.add_cell_inplace(xx, yy, self.actual_state2)
    
    def prepare(self):
        # This actually inserts a calculation, I don't think we want that?
        livecounts = self.get_live_counts()
        self.update_moving_avg(livecounts)

    def update_moving_avg(self, LiveCount livecounts):
        cdef int summ = 0
        cdef float running_avg
        cdef bint b1, b2, zerocells

        if not self.found_victor:
            maxdim = self.RUNNING_AVG_WINDOW_SIZE
            if self.generation < maxdim:
                self.running_avg_window[self.generation] = livecounts.victoryPct
            else:
                self.running_avg_window = self.running_avg_window[1:] + [livecounts.victoryPct]

            summ = sum(self.running_avg_window)
            running_avg = summ / (1.0 * len(self.running_avg_window))

            # update running average last 3
            removed = self.running_avg_last3[0]
            self.running_avg_last3 = self.running_avg_last3[1:] + [running_avg]

            # skip the first few steps where we're removing zeros
            if not self.approx_equal(removed, 0.0, self.TOL):
                b1 = self.approx_equal(
                    self.running_avg_last3[0], self.running_avg_last3[1], self.TOL
                )
                b2 = self.approx_equal(
                    self.running_avg_last3[1], self.running_avg_last3[2], self.TOL
                )
                zerocells = (
                    livecounts["liveCells1"] == 0 or livecounts["liveCells2"] == 0
                )

                if (b1 and b2) or zerocells:
                    z1 = self.approx_equal(self.running_avg_last3[0], 50.0, self.TOL)
                    z2 = self.approx_equal(self.running_avg_last3[1], 50.0, self.TOL)
                    z3 = self.approx_equal(self.running_avg_last3[2], 50.0, self.TOL)
                    if (not (z1 or z2 or z3)) or zerocells:
                        if livecounts["liveCells1"] > livecounts["liveCells2"]:
                            self.found_victor = True
                            self.who_won = 1
                        elif livecounts["liveCells1"] < livecounts["liveCells2"]:
                            self.found_victor = True
                            self.who_won = 2

    def approx_equal(self, float a, float b, float tol):
        return (abs(b - a) / abs(a + self.SMOL)) < tol

    def is_alive(self, int x, int y):
        """
        Boolean function: is the cell at x, y alive
        """
        for row in self.actual_state:
            if row[0] == y:
                for c in row[1:]:
                    if c == x:
                        return True

        return False

    def get_cell_color(self, int x, int y):
        """
        Get the color of the given cell (1 or 2)
        """
        for row in self.actual_state1:
            if row[0] == y:
                for c in row[1:]:
                    if c == x:
                        return 1
            elif row[0] > y:
                break

        for row in self.actual_state2:
            if row[0] == y:
                for c in row[1:]:
                    if c == x:
                        return 2
            elif row[0] > y:
                break

        return 0

    def remove_cell(self, int x, int y, vector[vector[int]] state):
        """
        Remove the given cell from the given listlife state
        """
        for i, row in enumerate(state):
            if row[0] == y:
                if len(row) == 2:
                    # Remove the entire row
                    state = state[:i] + state[i + 1 :]
                    return
                else:
                    j = indexOf(row, x)
                    state[i] = row[:j] + row[j + 1 :]

    def add_cell_inplace(self, int x, int y, vector[vector[int]] state):
        """
        Add the cell at (x, y) to the state
        """
        cdef vector[int] row_temp
        cdef vector[int] row_iter
        cdef int c
                    
        row_temp.clear()
        row_iter.clear()

        # Empty state case
        if len(state) == 0:
            row_temp.push_back(y)
            row_temp.push_back(x)
            state.push_back(row_temp)

        # Determine where in list to insert new cell
        if y < state[0][0]:
            # y is smaller than any existing y,
            # put this point at beginning
            row_temp.push_back(y)
            row_temp.push_back(x)

            state.insert(state.beginning(), row_temp)

        elif y > state[-1][0]:
            # y is larger than any existing y,
            # put this point at end
            row_temp.push_back(y)
            row_temp.push_back(x)
            state.push_back(row_temp)

        else:
            added = False
            for row_iter in state:
                if (not added) and (row_iter[0] == y):
                    # This is our level, it already exists
                    row_temp.push_back(y)
                    for c in range(1, len(row_iter)):
                        # Iterate over each x item in the list,
                        # stopping to insert our new x location
                        # in the correct location to preserve order
                        if (not added) and (x < row_iter[c]):
                            row_temp.push_back(x)
                            added = True
                        row_temp.push_back(row_iter[c])
                    # If we reach the end and have not added the new x,
                    # tack it on at the end
                    if not added:
                        row_temp.push_back(x)
                        added = True
                    state.push_back(row_temp)

                elif (not added) and (y < row_iter[0]):
                    # Our level does not exist, and should be inserted before the current row iterator.
                    # Create a new row and insert it before the current row.
                    row_temp.push_back(y)
                    row_temp.push_back(x)
                    state.push_back(row_temp)
                    state.push_back(row_iter)
                    added = True

                else:
                    # Pass current row along to the final state
                    state.push_back(row_iter)

            if added is False:
                raise Exception(f"Error adding cell ({x},{y}): temp row = {row_temp}")


    cdef _empty_neighbors():
        cdef vector[int] empty_neighbors
        cdef int i
        for i in range(3):
            empty_neighbors.push_back(-1)
        return empty_neighbors

    cdef get_neighbors_from_alive(self, int x, int y, int i, vector[vector[int]] state, int[8][3] possible_neighbors_list):
        """
        The following two functions look the same but are slightly different.
        This function is for dead cells that become alive.
        Below function is for dead cells that come alive because of these cells.
        """
        neighbors = 0
        neighbors1 = 0
        neighbors2 = 0

        cdef int[3] empty_neighbor = [-1, -1, -1]

        # 1 row above current cell
        if i >= 1:
            if state[i - 1][0] == (y - 1):
                for k in range(self.top_pointer, len(state[i - 1])):
                    if state[i - 1][k] >= (x - 1):
                        
                        # NW
                        if state[i - 1][k] == (x - 1):
                            possible_neighbors_list[0] = empty_neighbor
                            self.top_pointer = k + 1
                            neighbors += 1
                            xx = state[i - 1][k]
                            yy = state[i - 1][0]
                            neighborcolor = self.get_cell_color(xx, yy)
                            if neighborcolor == 1:
                                neighbors1 += 1
                            elif neighborcolor == 2:
                                neighbors2 += 1

                        # N
                        if state[i - 1][k] == x:
                            possible_neighbors_list[1] = empty_neighbor
                            self.top_pointer = k
                            neighbors += 1
                            xx = state[i - 1][k]
                            yy = state[i - 1][0]
                            neighborcolor = self.get_cell_color(xx, yy)
                            if neighborcolor == 1:
                                neighbors1 += 1
                            elif neighborcolor == 2:
                                neighbors2 += 1

                        # NE
                        if state[i - 1][k] == (x + 1):
                            possible_neighbors_list[2] = empty_neighbor
                            if k == 1:
                                self.top_pointer = 1
                            else:
                                self.top_pointer = k - 1
                            neighbors += 1
                            xx = state[i - 1][k]
                            yy = state[i - 1][0]
                            neighborcolor = self.get_cell_color(xx, yy)
                            if neighborcolor == 1:
                                neighbors1 += 1
                            elif neighborcolor == 2:
                                neighbors2 += 1

                        # Break it off early
                        if state[i - 1][k] > (x + 1):
                            break

        # The row of the current cell
        for k in range(1, len(state[i])):
            if state[i][k] >= (x - 1):

                # W
                if state[i][k] == (x - 1):
                    possible_neighbors_list[3] = empty_neighbor
                    neighbors += 1
                    xx = state[i][k]
                    yy = state[i][0]
                    neighborcolor = self.get_cell_color(xx, yy)
                    if neighborcolor == 1:
                        neighbors1 += 1
                    elif neighborcolor == 2:
                        neighbors2 += 1

                # E
                if state[i][k] == (x + 1):
                    possible_neighbors_list[4] = empty_neighbor
                    neighbors += 1
                    xx = state[i][k]
                    yy = state[i][0]
                    neighborcolor = self.get_cell_color(xx, yy)
                    if neighborcolor == 1:
                        neighbors1 += 1
                    elif neighborcolor == 2:
                        neighbors2 += 1

                # Break it off early
                if state[i][k] > (x + 1):
                    break

        # 1 row below current cell
        if i + 1 < len(state):
            if state[i + 1][0] == (y + 1):
                for k in range(self.bottom_pointer, len(state[i + 1])):
                    if state[i + 1][k] >= (x - 1):

                        # SW
                        if state[i + 1][k] == (x - 1):
                            possible_neighbors_list[5] = empty_neighbor
                            self.bottom_pointer = k + 1
                            neighbors += 1
                            xx = state[i + 1][k]
                            yy = state[i + 1][0]
                            neighborcolor = self.get_cell_color(xx, yy)
                            if neighborcolor == 1:
                                neighbors1 += 1
                            elif neighborcolor == 2:
                                neighbors2 += 1

                        # S
                        if state[i + 1][k] == x:
                            possible_neighbors_list[6] = empty_neighbor
                            self.bottom_pointer = k
                            neighbors += 1
                            xx = state[i + 1][k]
                            yy = state[i + 1][0]
                            neighborcolor = self.get_cell_color(xx, yy)
                            if neighborcolor == 1:
                                neighbors1 += 1
                            elif neighborcolor == 2:
                                neighbors2 += 1

                        # SE
                        if state[i + 1][k] == (x + 1):
                            possible_neighbors_list[7] = empty_neighbor
                            if k == 1:
                                self.bottom_pinter = 1
                            else:
                                self.bottom_pointer = k - 1
                            neighbors += 1
                            xx = state[i + 1][k]
                            yy = state[i + 1][0]
                            neighborcolor = self.get_cell_color(xx, yy)
                            if neighborcolor == 1:
                                neighbors1 += 1
                            elif neighborcolor == 2:
                                neighbors2 += 1

                        # Break it off early
                        if state[i + 1][k] > (x + 1):
                            break

        cdef int color = 0
        if neighbors1 > neighbors2:
            color = 1
        elif neighbors2 > neighbors1:
            color = 2
        else:
            if self.neighbor_color_legacy_mode:
                color = 1
            elif x % 2 == y % 2:
                color = 1
            else:
                color = 2

        return dict(neighbors=neighbors, color=color)

    def get_color_from_alive(self, int x, int y):
        """
        The above function is for dead cells that become alive.
        This function is for dead cells that come alive because of those cells.
        """
        cdef vector[vector[int]] state1 = self.actual_state1
        cdef vector[vector[int]] state2 = self.actual_state2

        cdef int color1 = 0, color2 = 0

        # Color 1
        for i in range(len(state1)):
            yy = state1[i][0]
            if yy == (y - 1):
                # 1 row above current cell
                for j in range(1, len(state1[i])):
                    xx = state1[i][j]
                    if xx >= (x - 1):
                        if xx == (x - 1):
                            # NW
                            color1 += 1
                        elif xx == x:
                            # N
                            color1 += 1
                        elif xx == (x + 1):
                            # NE
                            color1 += 1
                    if xx >= (x + 1):
                        break

            elif yy == y:
                # Row of current cell
                for j in range(1, len(state1[i])):
                    xx = state1[i][j]
                    if xx >= (x - 1):
                        if xx == (x - 1):
                            # W
                            color1 += 1
                        elif xx == (x + 1):
                            # E
                            color1 += 1
                    if xx >= (x + 1):
                        break

            elif yy == (y + 1):
                # 1 row below current cell
                for j in range(1, len(state1[i])):
                    xx = state1[i][j]
                    if xx >= (x - 1):
                        if xx == (x - 1):
                            # SW
                            color1 += 1
                        elif xx == x:
                            # S
                            color1 += 1
                        elif xx == (x + 1):
                            # SE
                            color1 += 1
                    if xx >= (x + 1):
                        break

        # color2
        for i in range(len(state2)):
            yy = state2[i][0]
            if yy == (y - 1):
                # 1 row above current cell
                for j in range(1, len(state2[i])):
                    xx = state2[i][j]
                    if xx >= (x - 1):
                        if xx == (x - 1):
                            # NW
                            color2 += 1
                        elif xx == x:
                            # N
                            color2 += 1
                        elif xx == (x + 1):
                            # NE
                            color2 += 1
                    if xx >= (x + 1):
                        break

            elif yy == y:
                # Row of current cell
                for j in range(1, len(state2[i])):
                    xx = state2[i][j]
                    if xx >= (x - 1):
                        if xx == (x - 1):
                            # W
                            color2 += 1
                        elif xx == (x + 1):
                            # E
                            color2 += 1
                    if xx >= (x + 1):
                        break

            elif yy == (y + 1):
                # 1 row below current cell
                for j in range(1, len(state2[i])):
                    xx = state2[i][j]
                    if xx >= (x - 1):
                        if xx == (x - 1):
                            # SW
                            color2 += 1
                        elif xx == x:
                            # S
                            color2 += 1
                        elif xx == (x + 1):
                            # SE
                            color2 += 1
                    if xx >= (x + 1):
                        break

        if color1 > color2:
            return 1
        elif color1 < color2:
            return 2
        else:
            if self.neighbor_color_legacy_mode:
                color = 1
            elif x % 2 == y % 2:
                color = 1
            else:
                color = 2
            return color

    cdef next_generation(self):
        """
        Evolve the actual_state list life state to the next generation.
        """
        all_dead_neighbors = {}

        cdef vector[vector[int]] new_state = []
        cdef vector[vector[int]] new_state1 = []
        cdef vector[vector[int]] new_state2 = []

        cdef vector[int] redraw_templist

        self.redraw_list.clear()

        cdef int i, j, k
        cdef int x, y
        cdef int color
        cdef int neighbors
        cdef int[8][3] dead_neighbors
        cdef int[3] dead_neighbor

        for i in range(len(self.actual_state)):
            self.top_pointer = 1
            self.bottom_pointer = 1

            for j in range(1, len(self.actual_state[i])):

                x = self.actual_state[i][j]
                y = self.actual_state[i][0]

                # create a list of possible dead neighbors
                # get_neighbors_from_alive() will pare this down
                dead_neighbors[0] = [x - 1, y - 1, 1]
                dead_neighbors[1] = [x, y - 1, 1]
                dead_neighbors[2] = [x + 1, y - 1, 1]
                dead_neighbors[3] = [x - 1, y, 1]
                dead_neighbors[4] = [x + 1, y, 1]
                dead_neighbors[5] = [x - 1, y + 1, 1]
                dead_neighbors[6] = [x, y + 1, 1]
                dead_neighbors[7] = [x + 1, y + 1, 1]

                result = self.get_neighbors_from_alive(
                    x, y, i, self.actual_state, dead_neighbors
                )
                neighbors = result["neighbors"]
                color = result["color"]

                # join dead neighbors remaining to check list
                for dead_neighbor in dead_neighbors:
                    if dead_neighbor[2] != -1:
                        # this cell is dead
                        xx = dead_neighbor[0]
                        yy = dead_neighbor[1]
                        key = str(xx) + "," + str(yy)

                        # counting number of dead neighbors
                        if key not in all_dead_neighbors:
                            all_dead_neighbors[key] = 1
                        else:
                            all_dead_neighbors[key] += 1

                if not (neighbors == 0 or neighbors == 1 or neighbors > 3):
                    new_state = self.add_cell(x, y, new_state)
                    if color == 1:
                        new_state1 = self.add_cell(x, y, new_state1)
                    elif color == 2:
                        new_state2 = self.add_cell(x, y, new_state2)
                    # Keep cell alive
                    redraw_templist.clear()
                    redraw_templist.push_back(x)
                    redraw_templist.push_back(y)
                    redraw_templist.push_back(2)
                    self.redraw_list.push_back(redraw_templist)
                else:
                    # Kill cell
                    redraw_templist.clear()
                    redraw_templist.push_back(x)
                    redraw_templist.push_back(y)
                    redraw_templist.push_back(0)
                    self.redraw_list.push_back(redraw_templist)

        # Process dead neighbors
        for key in all_dead_neighbors:
            if all_dead_neighbors[key] == 3:
                # This cell is dead, but has enough neighbors
                # that are alive that it will make new life
                key = key.split(",")
                t1 = int(key[0])
                t2 = int(key[1])

                # Get color from neighboring parent cells
                color = self.get_color_from_alive(t1, t2)

                new_state = self.add_cell(t1, t2, new_state)
                if color == 1:
                    new_state1 = self.add_cell(t1, t2, new_state1)
                elif color == 2:
                    new_state2 = self.add_cell(t1, t2, new_state2)

                redraw_templist.clear()
                redraw_templist.push_back(t1)
                redraw_templist.push_back(t2)
                redraw_templist.push_back(1)
                self.redraw_list.push_back(redraw_templist)

        self.actual_state = new_state
        self.actual_state1 = new_state1
        self.actual_state2 = new_state2

        return self.get_live_counts()

    def _count_live_cells(self, vector[vector[int]] state):
        cdef int livecells = 0
        cdef int statelength = len(state)

        for i in range(statelength):
            if (state[i][0] >= 0) and (state[i][0] < self.rows):
                for j in range(1, len(state[i])):
                    if (state[i][j] >= 0) and (state[i][j] < self.columns):
                        livecells += 1
        return livecells

    def get_live_counts(self):
        cdef float victory
        cdef float SMOL

        self.livecells  = self._count_live_cells(self.actual_state)
        self.livecells1 = self._count_live_cells(self.actual_state1)
        self.livecells2 = self._count_live_cells(self.actual_state2)

        self.victory = 0
        if self.livecells1 > self.livecells2:
            self.victory = (self.livecells1 / (1.0 * self.livecells1 + self.livecells2 + self.SMOL))*100
        else:
            self.victory = (self.livecells2 / (1.0 * self.livecells1 + self.livecells2 + self.SMOL))*100

        self.coverage = (self.livecells / (1.0 * self.columns * self.rows))*100

        self.territory1 = (self.livecells1 / (1.0 * self.columns * self.rows))*100
        self.territory2 = (self.livecells2 / (1.0 * self.columns * self.rows))*100

        lc = LiveCount(
            generation=self.generation,
            liveCells=self.livecells,
            liveCells1=self.livecells1,
            liveCells2=self.livecells2,
            victoryPct=self.victory,
            coverage=self.coverage,
            territory1=self.territory1,
            territory2=self.territory2,
        )
        return lc

    def next_step(self):
        if self.running is False:
            return self.get_live_counts()
        elif self.halt and self.found_victor:
            self.running = False
            return self.get_live_counts()
        else:
            self.generation += 1
            live_counts = self.next_generation()
            self.update_moving_avg(live_counts)
            return live_counts
